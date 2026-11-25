import Foundation

/// A custom filter from the Radarr or Sonarr web interface (`/api/v3/customfilter`), which Ruddarr only reads.
///
/// Filters are checked like the web interface checks them: every condition must pass, and a condition
/// whose value is an array passes when any element does (every element for `notContains` and `notEqual`).
struct CustomFilter: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let type: String
    let label: String
    let filters: [Condition]

    struct Condition: Hashable, Codable, Sendable {
        let key: String
        let value: Value
        /// The operator, such as `contains` or `inLast`. The web interface treats a missing one as `equal`.
        let type: String?
    }

    /// Any JSON value. The web interface stores an array, such as `[2, 5]` or `["released"]`, except for
    /// dates, which store a `"yyyy-mm-dd"` string or a `{ "time": "days", "value": 30 }` object.
    enum Value: Hashable, Codable, Sendable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([Value])
        case object([String: Value])

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([Value].self) {
                self = .array(value)
            } else {
                self = .object(try container.decode([String: Value].self))
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .null: try container.encodeNil()
            case .bool(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
            }
        }
    }
}

/// A grid item that custom filters can check: `Movie` or `Series`.
protocol CustomFilterable {
    /// The item's value for each key Ruddarr can check. `nil` when the item has none, which never matches.
    static var customFilterValues: [String: @Sendable (Self) -> CustomFilterItemValue?] { get }
}

/// An item's value for a filter key.
enum CustomFilterItemValue: Sendable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case numbers([Double])
    case strings([String])
    /// A date. `nil` never matches, as in the web interface.
    case date(Date?)

    /// A `Float` as the number its JSON text was, so `7.3` stays `7.3`, times `scale` for ratings the web interface multiplies by 10.
    static func decimal(_ value: Float, scale: Double = 1) -> Self {
        .number((Double(String(value)) ?? Double(value)) * scale)
    }
}

extension CustomFilter {
    /// Whether Ruddarr knows every condition's key and operator, so it can apply the filter.
    func isSupported<Item: CustomFilterable>(for _: Item.Type) -> Bool {
        filters.allSatisfy { Item.customFilterValues[$0.key] != nil && $0.operator != nil }
    }

    func matches<Item: CustomFilterable>(_ item: Item, now: Date = .now) -> Bool {
        filters.allSatisfy { condition in
            guard let value = Item.customFilterValues[condition.key]?(item) else { return false }
            return condition.matches(value, now: now)
        }
    }
}

extension CustomFilter.Condition {
    enum Operator: String {
        case contains, notContains, equal, notEqual
        case greaterThan, greaterThanOrEqual, lessThan, lessThanOrEqual
        case startsWith, notStartsWith, endsWith, notEndsWith
        case inLast, notInLast, inNext, notInNext
    }

    var `operator`: Operator? {
        Operator(rawValue: type ?? Operator.equal.rawValue)
    }

    func matches(_ item: CustomFilterItemValue, now: Date) -> Bool {
        guard let op = `operator` else { return false }

        let values = if case .array(let elements) = value { elements } else { [value] }
        let passes = { (value: CustomFilter.Value) in item.passes(value, op, now: now) }

        return op == .notContains || op == .notEqual ? values.allSatisfy(passes) : values.contains(where: passes)
    }
}

private extension CustomFilterItemValue {
    typealias Operator = CustomFilter.Condition.Operator

    /// The web interface's predicate for one value.
    func passes(_ value: CustomFilter.Value, _ op: Operator, now: Date) -> Bool {
        if case .date(let date) = self {
            return Self.date(date, passes: value, op, now: now)
        }

        return switch op {
        case .equal: equals(value)
        case .notEqual: !equals(value)
        case .contains: contains(value)
        case .notContains: !contains(value)
        case .startsWith, .endsWith: hasAffix(value, atEnd: op == .endsWith)
        case .notStartsWith, .notEndsWith: !hasAffix(value, atEnd: op == .notEndsWith)
        case .greaterThan, .greaterThanOrEqual, .lessThan, .lessThanOrEqual: compare(value, op)
        case .inLast, .notInLast, .inNext, .notInNext: false
        }
    }

    /// Before and after are exclusive, as in the web interface.
    static func date(_ date: Date?, passes value: CustomFilter.Value, _ op: Operator, now: Date) -> Bool {
        guard let date, let bound = value.dateBound(for: op, now: now) else { return false }

        return switch op {
        case .lessThan, .notInLast: date < bound
        case .greaterThan, .notInNext: date > bound
        case .inLast: date > bound && date < now
        case .inNext: date > now && date < bound
        default: false
        }
    }

    func compare(_ value: CustomFilter.Value, _ op: Operator) -> Bool {
        guard case .number(let lhs) = self, case .number(let rhs) = value else { return false }

        return switch op {
        case .greaterThan: lhs > rhs
        case .greaterThanOrEqual: lhs >= rhs
        case .lessThan: lhs < rhs
        default: lhs <= rhs
        }
    }

    /// A case-insensitive prefix or suffix of a string.
    func hasAffix(_ value: CustomFilter.Value, atEnd: Bool) -> Bool {
        guard case .string(let string) = self, case .string(let affix) = value else { return false }

        return atEnd ? string.lowercased().hasSuffix(affix.lowercased()) : string.lowercased().hasPrefix(affix.lowercased())
    }

    /// JavaScript's `===`: no type coercion, and arrays never equal a value.
    func equals(_ value: CustomFilter.Value) -> Bool {
        switch (self, value) {
        case (.bool(let lhs), .bool(let rhs)): lhs == rhs
        case (.number(let lhs), .number(let rhs)): lhs == rhs
        case (.string(let lhs), .string(let rhs)): lhs == rhs
        default: false
        }
    }

    /// Membership for arrays, a case-insensitive substring for strings.
    func contains(_ value: CustomFilter.Value) -> Bool {
        switch (self, value) {
        case (.numbers(let list), .number(let number)): list.contains(number)
        case (.strings(let list), .string(let string)): list.contains(string)
        case (.string(let string), .string(let needle)): needle.isEmpty || string.lowercased().contains(needle.lowercased())
        default: false
        }
    }
}

private extension CustomFilter.Value {
    // The web interface uses Gregorian dates in the device's time zone.
    static let calendar = Calendar(identifier: .gregorian)

    static let units: [String: Calendar.Component] = [
        "seconds": .second, "minutes": .minute, "hours": .hour, "days": .day, "weeks": .weekOfYear, "months": .month,
    ]

    /// Local midnight of a `"yyyy-mm-dd"` string for before and after, or `now` moved by
    /// a `{ "time": "days", "value": 30 }` object for in and not in the last or next.
    func dateBound(for op: CustomFilter.Condition.Operator, now: Date) -> Date? {
        switch (op, self) {
        case (.lessThan, .string(let string)), (.greaterThan, .string(let string)):
            return try? Date.ISO8601FormatStyle(timeZone: .current).year().month().day().parse(string)
        case (.inLast, .object(let object)), (.notInLast, .object(let object)), (.inNext, .object(let object)), (.notInNext, .object(let object)):
            guard case .string(let time) = object["time"], let unit = Self.units[time] else { return nil }

            // The web interface stores `null` until a number is typed, and counts it as 0.
            let amount: Int? = if case .number(let number) = object["value"] { Int(exactly: number) } else { 0 }
            guard let amount else { return nil }

            return Self.calendar.date(byAdding: unit, value: op == .inNext || op == .notInNext ? amount : -amount, to: now)
        default:
            return nil
        }
    }
}
