import Foundation

// Evaluates custom filters like the Radarr and Sonarr v4 web UI (`createClientSideCollectionSelector`,
// `filterTypePredicates` and `dateFilterPredicate`). Where the web UI would throw, such as calling a
// string operator on a number, the condition fails instead.
extension CustomFilter {
    /// The conditions Ruddarr can't evaluate for `Item`: an unknown key or operator, or a value it can't read.
    func unsupportedConditions<Item: CustomFilterable>(for item: Item.Type) -> [CustomFilterCondition] {
        conditions.filter { !$0.isSupported(for: item) }
    }

    /// Whether Ruddarr can evaluate every condition of this filter for `Item`.
    func isSupported<Item: CustomFilterable>(for item: Item.Type) -> Bool {
        unsupportedConditions(for: item).isEmpty
    }

    /// Whether `item` passes every condition, evaluated like the Radarr/Sonarr web UI.
    func matches<Item: CustomFilterable>(_ item: Item, now: Date = .now, calendar: Calendar = .current) -> Bool {
        conditions.allSatisfy { $0.matches(item, now: now, calendar: calendar) }
    }
}

extension CustomFilterable {
    /// The distinct, sorted string values of `key` across `items`, for `.libraryValues` fields.
    static func libraryValues(for key: String, in items: [Self]) -> [String] {
        var values: Set<String> = []

        for item in items {
            switch item.customFilterValue(for: key) {
            case .string(let value) where !value.isEmpty: values.insert(value)
            case .strings(let list): values.formUnion(list.filter { !$0.isEmpty })
            default: break
            }
        }

        return values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

extension CustomFilterCondition {
    /// Whether Ruddarr can evaluate this condition for `Item`.
    func isSupported<Item: CustomFilterable>(for item: Item.Type) -> Bool {
        let field = Item.customFilterFields.first { $0.key == key }

        guard field != nil || Item.customFilterHiddenKeys.contains(key) else { return false }
        guard let `operator` else { return false }

        if field?.builder == .date {
            return value.elements.allSatisfy { $0.isReadableDate(for: `operator`) }
        }

        // The web UI has no generic predicate for relative dates, so it would throw.
        if `operator`.isRelativeDate {
            return false
        }

        return value.elements.allSatisfy(\.isScalar)
    }

    /// Whether `item` passes this condition, following the web UI's filter loop.
    func matches<Item: CustomFilterable>(_ item: Item, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let itemValue = item.customFilterValue(for: key)

        // An array value needs every element to pass for `notContains`/`notEqual`, otherwise any one.
        let isNegative = type == CustomFilterOperator.notContains.rawValue || type == CustomFilterOperator.notEqual.rawValue

        switch itemValue {
        case .unsupported, .missing:
            return false
        case .result(let result):
            // The predicate ignores the value and operator, but still runs once per array element.
            guard case .array(let values) = value else { return result }
            return isNegative ? (values.isEmpty || result) : (!values.isEmpty && result)
        default:
            break
        }

        guard let `operator` else { return false }

        let gregorian = calendar.identifier == .gregorian ? calendar : Calendar.gregorian(in: calendar.timeZone)

        func test(_ filterValue: CustomFilterValue) -> Bool {
            itemValue.passes(filterValue, `operator`, now: now, calendar: gregorian)
        }

        guard case .array(let values) = value else {
            return test(value)
        }

        return isNegative ? values.allSatisfy(test) : values.contains(where: test)
    }
}

extension CustomFilterOperator {
    /// `inLast`, `notInLast`, `inNext` and `notInNext`, which take a `{ time, value }` object.
    var isRelativeDate: Bool {
        switch self {
        case .inLast, .notInLast, .inNext, .notInNext: true
        default: false
        }
    }
}

/// A relative date value, `{ "time": "days", "value": 30 }`. A `null` or absent `value` means 0.
struct CustomFilterRelativeDate: Hashable, Sendable {
    let unit: CustomFilterTimeUnit
    let amount: Double

    init(unit: CustomFilterTimeUnit, amount: Double) {
        self.unit = unit
        self.amount = amount
    }

    init?(_ value: CustomFilterValue) {
        guard case .object(let object) = value,
              case .string(let time) = object["time"],
              let unit = CustomFilterTimeUnit(rawValue: time)
        else { return nil }

        switch object["value"] {
        case nil, .null: amount = 0
        case .int(let number): amount = Double(number)
        case .double(let number) where number.isFinite: amount = number
        default: return nil
        }

        self.unit = unit
    }

    var value: CustomFilterValue {
        let number: CustomFilterValue = amount.rounded() == amount && abs(amount) < 1e15
            ? .int(Int(amount))
            : .double(amount)

        return .object(["time": .string(unit.rawValue), "value": number])
    }

    /// `now` moved by `amount` units (negated when `forward` is false), like `moment().add()`:
    /// seconds to hours are exact, days, weeks and months are rounded and calendar-aware.
    func date(from now: Date, forward: Bool, calendar: Calendar) -> Date? {
        let amount = forward ? amount : -amount

        switch unit {
        case .seconds: return now.addingTimeInterval(amount)
        case .minutes: return now.addingTimeInterval(amount * 60)
        case .hours: return now.addingTimeInterval(amount * 3_600)
        case .days: return Self.add(.day, amount, to: now, calendar)
        case .weeks: return Self.add(.day, amount * 7, to: now, calendar)
        case .months: return Self.add(.month, amount, to: now, calendar)
        }
    }

    private static func add(_ component: Calendar.Component, _ amount: Double, to date: Date, _ calendar: Calendar) -> Date? {
        // moment rounds day and month offsets half away from zero.
        let rounded = amount.rounded(.toNearestOrAwayFromZero)
        guard abs(rounded) < 1_000_000 else { return nil }

        return calendar.date(byAdding: component, value: Int(rounded), to: date)
    }
}

extension CustomFilterValue {
    /// The elements of an array value, or the value itself.
    fileprivate var elements: [CustomFilterValue] {
        if case .array(let values) = self { return values }
        return [self]
    }

    fileprivate var isScalar: Bool {
        switch self {
        case .null, .bool, .int, .double, .string: true
        case .array, .object: false
        }
    }

    fileprivate func isReadableDate(for operator: CustomFilterOperator) -> Bool {
        switch `operator` {
        case .lessThan, .greaterThan: localMidnight(in: .gregorian(in: .gmt)) != nil
        case .inLast, .notInLast, .inNext, .notInNext: CustomFilterRelativeDate(self) != nil
        // `dateFilterPredicate` returns false for every other operator.
        default: true
        }
    }

    /// Local midnight of a `"yyyy-mm-dd"` string, as `moment("2024-01-31")` parses it.
    func localMidnight(in calendar: Calendar) -> Date? {
        guard case .string(let string) = self,
              let match = string.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
              let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else { return nil }

        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }

        return calendar.date(from: components)
    }

    /// The value as JS `Number()` would coerce it for `<`/`>`, or `nil` for NaN.
    fileprivate var numericValue: Double? {
        switch self {
        case .null: 0
        case .bool(let value): value ? 1 : 0
        case .int(let value): Double(value)
        case .double(let value): value
        case .string(let value): value.numericValue
        case .array, .object: nil
        }
    }
}

extension CustomFilterItemValue {
    // The generic `filterTypePredicates`, or `dateFilterPredicate` for dates.
    // swiftlint:disable:next cyclomatic_complexity
    fileprivate func passes(_ filterValue: CustomFilterValue, _ operator: CustomFilterOperator, now: Date, calendar: Calendar) -> Bool {
        if case .date(let date) = self {
            return Self.date(date, passes: filterValue, `operator`, now: now, calendar: calendar)
        }

        return switch `operator` {
        case .equal: strictlyEquals(filterValue)
        case .notEqual: !strictlyEquals(filterValue)
        case .contains: contains(filterValue) ?? false
        case .notContains: contains(filterValue).map { !$0 } ?? false
        case .startsWith: hasAffix(filterValue, backwards: false) ?? false
        case .notStartsWith: hasAffix(filterValue, backwards: false).map { !$0 } ?? false
        case .endsWith: hasAffix(filterValue, backwards: true) ?? false
        case .notEndsWith: hasAffix(filterValue, backwards: true).map { !$0 } ?? false
        case .greaterThan: compare(to: filterValue) == .orderedDescending
        case .greaterThanOrEqual: compare(to: filterValue).map { $0 != .orderedAscending } ?? false
        case .lessThan: compare(to: filterValue) == .orderedAscending
        case .lessThanOrEqual: compare(to: filterValue).map { $0 != .orderedDescending } ?? false
        case .inLast, .notInLast, .inNext, .notInNext: false
        }
    }

    /// JS `===`: no type coercion, case-sensitive strings, and arrays never equal a value.
    private func strictlyEquals(_ filterValue: CustomFilterValue) -> Bool {
        switch (self, filterValue) {
        case (.bool(let lhs), .bool(let rhs)): lhs == rhs
        case (.number(let lhs), .int(let rhs)): lhs == Double(rhs)
        case (.number(let lhs), .double(let rhs)): lhs == rhs
        case (.string(let lhs), .string(let rhs)): lhs.utf16.elementsEqual(rhs.utf16)
        default: false
        }
    }

    /// Strict membership for arrays, a case-insensitive substring test for strings, otherwise `nil` (the web UI throws).
    private func contains(_ filterValue: CustomFilterValue) -> Bool? {
        switch self {
        case .numbers(let list):
            return list.contains { Self.number($0).strictlyEquals(filterValue) }
        case .strings(let list):
            return list.contains { Self.string($0).strictlyEquals(filterValue) }
        case .string(let string):
            guard case .string(let needle) = filterValue else { return nil }
            return needle.isEmpty || string.lowercased().range(of: needle.lowercased(), options: .literal) != nil
        default:
            return nil
        }
    }

    /// A case-insensitive prefix or suffix test on strings, otherwise `nil` (the web UI throws).
    private func hasAffix(_ filterValue: CustomFilterValue, backwards: Bool) -> Bool? {
        guard case .string(let string) = self, case .string(let affix) = filterValue else { return nil }
        guard !affix.isEmpty else { return true }

        let options: String.CompareOptions = backwards ? [.literal, .anchored, .backwards] : [.literal, .anchored]

        return string.lowercased().range(of: affix.lowercased(), options: options) != nil
    }

    /// JS relational comparison: strings by UTF-16 code units, everything else as numbers. `nil` for NaN.
    private func compare(to filterValue: CustomFilterValue) -> ComparisonResult? {
        if case .string(let lhs) = self, case .string(let rhs) = filterValue {
            let left = Array(lhs.utf16), right = Array(rhs.utf16)
            if left == right { return .orderedSame }
            return left.lexicographicallyPrecedes(right) ? .orderedAscending : .orderedDescending
        }

        let lhs: Double? = switch self {
        case .bool(let value): value ? 1 : 0
        case .number(let value): value
        case .string(let value): value.numericValue
        default: nil
        }

        guard let lhs, let rhs = filterValue.numericValue, !lhs.isNaN, !rhs.isNaN else { return nil }

        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// `dateFilterPredicate`: a missing date never matches, and the bounds are strict.
    private static func date(
        _ date: Date?, passes filterValue: CustomFilterValue, _ operator: CustomFilterOperator, now: Date, calendar: Calendar
    ) -> Bool {
        guard let date else { return false }

        switch `operator` {
        case .lessThan, .greaterThan:
            guard let bound = filterValue.localMidnight(in: calendar) else { return false }
            return `operator` == .lessThan ? date < bound : date > bound
        case .inLast, .notInLast, .inNext, .notInNext:
            guard let relative = CustomFilterRelativeDate(filterValue),
                  let bound = relative.date(from: now, forward: `operator` == .inNext || `operator` == .notInNext, calendar: calendar)
            else { return false }

            return switch `operator` {
            case .inLast: date > bound && date < now
            case .notInLast: date < bound
            case .inNext: date > now && date < bound
            default: date > bound
            }
        default:
            return false
        }
    }
}

extension String {
    /// JS `Number(string)`: whitespace is trimmed and an empty string is 0.
    fileprivate var numericValue: Double? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return Double(trimmed)
    }
}

extension Calendar {
    /// moment uses Gregorian dates in the device's time zone, whatever the user's calendar.
    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension CustomFilterItemValue {
    /// A `Float` from the API as the number its JSON text was, so `7.3` stays `7.3` rather than `7.300000190734863`,
    /// multiplied by `scale` like the web UI's ×10 rating predicates.
    static func decimal(_ value: Float, scale: Double = 1) -> Self {
        .number((Double(String(value)) ?? Double(value)) * scale)
    }
}
