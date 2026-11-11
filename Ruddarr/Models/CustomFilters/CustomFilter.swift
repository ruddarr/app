import Foundation

/// A saved filter for the Movies or Series grid.
///
/// Uses the same conditions the Radarr/Sonarr web UI stores at `/api/v3/customfilter`, so a filter
/// can live in the app only (`.app`) or on the server (`.server`), where the web UI shows it too.
struct CustomFilter: Identifiable, Hashable, Codable, Sendable {
    var id: Identifier
    var label: String
    var conditions: [CustomFilterCondition]

    enum Identifier: Hashable, Codable, Sendable {
        /// Saved in the app, on this device.
        case app(UUID)
        /// Saved on the Radarr/Sonarr server, with the server's id.
        case server(Int)
    }

    var isOnServer: Bool {
        if case .server = id { return true }
        return false
    }
}

/// One row of a custom filter: `{ "key": …, "value": …, "type": … }` on the wire.
///
/// `type` is the operator's raw string. It is kept as a string so operators Ruddarr doesn't know
/// round-trip unchanged when a filter is saved again. A row without `type` means `equal`.
struct CustomFilterCondition: Hashable, Codable, Sendable {
    var key: String
    var value: CustomFilterValue
    var type: String

    init(key: String, value: CustomFilterValue, type: String) {
        self.key = key
        self.value = value
        self.type = type
    }

    init(key: String, value: CustomFilterValue, operator: CustomFilterOperator) {
        self.init(key: key, value: value, type: `operator`.rawValue)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decodeIfPresent(CustomFilterValue.self, forKey: .value) ?? .null
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? CustomFilterOperator.equal.rawValue
    }

    /// `nil` when `type` is an operator Ruddarr doesn't know.
    var `operator`: CustomFilterOperator? {
        CustomFilterOperator(rawValue: type)
    }
}

/// Any JSON value, as stored in a condition's `value`.
///
/// Builder-made filters store an array (`[2, 5]`, `["released"]`, `[true]`), except dates, which store
/// a `"yyyy-mm-dd"` string or a `{ "time": "days", "value": 30 }` object. Integers decode as `.int`
/// so tag and profile ids stay integers when the filter is saved back to the server.
enum CustomFilterValue: Hashable, Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([CustomFilterValue])
    case object([String: CustomFilterValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CustomFilterValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: CustomFilterValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

/// The operators of the web UI's filter builder (`filterTypes`).
enum CustomFilterOperator: String, CaseIterable, Identifiable, Sendable {
    var id: Self { self }

    case contains
    case notContains
    case equal
    case notEqual
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case startsWith
    case notStartsWith
    case endsWith
    case notEndsWith
    case inLast
    case notInLast
    case inNext
    case notInNext
}

/// How the web UI's builder treats a field (`filterBuilderTypes`). Decides the operators offered.
enum CustomFilterBuilderType: Sendable {
    case array
    case contains
    case date
    case equal
    case exact
    case number
    case string

    /// The operators the web UI offers for this builder type, in its order. The first is the default.
    var operators: [CustomFilterOperator] {
        switch self {
        case .array: [.contains, .notContains]
        case .contains: [.contains]
        case .date: [.lessThan, .greaterThan, .inLast, .notInLast, .inNext, .notInNext]
        case .equal: [.equal]
        case .exact: [.equal, .notEqual]
        case .number: [.equal, .greaterThan, .greaterThanOrEqual, .lessThan, .lessThanOrEqual, .notEqual]
        case .string: [.contains, .notContains, .equal, .notEqual, .startsWith, .notStartsWith, .endsWith, .notEndsWith]
        }
    }
}

/// What kind of value a field takes, which decides the value editor in the builder.
enum CustomFilterValueKind: Hashable, Sendable {
    /// Free-form strings.
    case text
    /// Free-form numbers.
    case number
    /// A size in bytes, entered with a unit.
    case bytes
    /// A `"yyyy-mm-dd"` string for before/after, or a `{ time, value }` object for in/not in last/next.
    case date
    /// `true` or `false`.
    case bool
    /// The instance's tag ids.
    case tag
    /// The instance's quality profile ids.
    case qualityProfile
    /// A fixed list of values, such as statuses.
    case options([CustomFilterOption])
    /// The distinct values of this field found in the library, such as genres or studios.
    case libraryValues
}

struct CustomFilterOption: Hashable, Identifiable, Sendable {
    let value: CustomFilterValue
    let label: String

    var id: CustomFilterValue { value }
}

/// A field the builder offers, such as `tags` or `added`.
struct CustomFilterField: Identifiable, Sendable {
    let key: String
    let label: String
    let builder: CustomFilterBuilderType
    let kind: CustomFilterValueKind
    /// The section the builder lists this field in.
    var group: CustomFilterFieldGroup = .metadata

    var id: String { key }
}

/// The sections of the builder's field list, in display order.
enum CustomFilterFieldGroup: CaseIterable, Identifiable, Sendable {
    var id: Self { self }

    case status
    case library
    case dates
    case ratings
    case metadata
}

/// The units of a relative date value, `{ "time": <unit>, "value": <n> }`. The web UI has no years.
enum CustomFilterTimeUnit: String, CaseIterable, Identifiable, Sendable {
    var id: Self { self }

    case seconds
    case minutes
    case hours
    case days
    case weeks
    case months
}

/// The value an item has for a filter key, ready for comparison.
enum CustomFilterItemValue: Sendable {
    /// Ruddarr can't evaluate this key.
    case unsupported
    /// The item has no value for this key; the web UI rejects the item.
    case missing
    case bool(Bool)
    case number(Double)
    case string(String)
    case numbers([Double])
    case strings([String])
    /// A date; `nil` never matches, as in the web UI.
    case date(Date?)
    /// A key whose web UI predicate ignores the value and operator, such as Sonarr's `missing`.
    case result(Bool)
}

/// A library item that custom filters can match: `Movie` and `Series`.
protocol CustomFilterable: Sendable {
    /// The server's `type` for this grid's custom filters: `movieIndex` in Radarr, `series` in Sonarr.
    static var customFilterType: String { get }

    /// The fields the builder offers, in the web UI's order. Only fields Ruddarr can evaluate.
    static var customFilterFields: [CustomFilterField] { get }

    /// Keys the builder doesn't offer but the web UI can still evaluate, such as Radarr's `hasFile`,
    /// which its predefined filters use. Conditions with these keys are supported.
    static var customFilterHiddenKeys: Set<String> { get }

    /// The item's value for `key`, following the web UI's predicate for that key.
    func customFilterValue(for key: String) -> CustomFilterItemValue
}

extension CustomFilterable {
    static var customFilterHiddenKeys: Set<String> { [] }
}
