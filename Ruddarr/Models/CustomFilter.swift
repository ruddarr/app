import Foundation

struct CustomFilter: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let type: String
    let label: String
    let filters: [Condition]

    struct Condition: Hashable, Codable, Sendable {
        let key: String
        let value: Value
        let type: String?
    }

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

protocol CustomFilterable {
    static var customFilterValues: [String: @Sendable (Self) -> CustomFilterItemValue?] { get }
}

enum CustomFilterItemValue: Sendable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case numbers([Double])
    case strings([String])
    case date(Date?)

    static func decimal(_ value: Float, scale: Double = 1) -> Self {
        .number((Double(String(value)) ?? Double(value)) * scale)
    }
}

extension CustomFilter {
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

    func hasAffix(_ value: CustomFilter.Value, atEnd: Bool) -> Bool {
        guard case .string(let string) = self, case .string(let affix) = value else { return false }

        return atEnd ? string.lowercased().hasSuffix(affix.lowercased()) : string.lowercased().hasPrefix(affix.lowercased())
    }

    func equals(_ value: CustomFilter.Value) -> Bool {
        switch (self, value) {
        case (.bool(let lhs), .bool(let rhs)): lhs == rhs
        case (.number(let lhs), .number(let rhs)): lhs == rhs
        case (.string(let lhs), .string(let rhs)): lhs == rhs
        default: false
        }
    }

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
    static let calendar = Calendar(identifier: .gregorian)

    static let units: [String: Calendar.Component] = [
        "seconds": .second, "minutes": .minute, "hours": .hour, "days": .day, "weeks": .weekOfYear, "months": .month,
    ]

    func dateBound(for op: CustomFilter.Condition.Operator, now: Date) -> Date? {
        switch (op, self) {
        case (.lessThan, .string(let string)), (.greaterThan, .string(let string)):
            return try? Date.ISO8601FormatStyle(timeZone: .current).year().month().day().parse(string)
        case (.inLast, .object(let object)), (.notInLast, .object(let object)), (.inNext, .object(let object)), (.notInNext, .object(let object)):
            guard case .string(let time) = object["time"], let unit = Self.units[time] else { return nil }

            let amount: Int? = if case .number(let number) = object["value"] { Int(exactly: number) } else { 0 }
            guard let amount else { return nil }

            return Self.calendar.date(byAdding: unit, value: op == .inNext || op == .notInNext ? amount : -amount, to: now)
        default:
            return nil
        }
    }
}
