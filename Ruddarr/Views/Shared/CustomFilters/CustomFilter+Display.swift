import SwiftUI

/// What the filter views need from the instance a filter belongs to.
struct CustomFilterContext<Item: CustomFilterable> {
    let filters: CustomFilters
    /// "Radarr" or "Sonarr".
    let serverName: String
    let tags: [Tag]
    let qualityProfiles: [InstanceQualityProfile]
    let items: [Item]
}

extension CustomFilters {
    var alertBinding: Binding<Bool> {
        .init(get: { self.error != nil }, set: { _ in })
    }
}

extension CustomFilter {
    /// A new, empty filter saved in the app.
    static func new() -> CustomFilter {
        CustomFilter(id: .app(UUID()), label: "", conditions: [])
    }
}

extension CustomFilterOperator {
    /// A short, sentence-friendly label for this operator, which depends on the builder type for some operators.
    func label(for builder: CustomFilterBuilderType) -> String {
        switch (self, builder) {
        case (.greaterThan, .date): String(localized: "is after", comment: "Custom filter operator")
        case (.lessThan, .date): String(localized: "is before", comment: "Custom filter operator")
        default: genericLabel
        }
    }

    private var genericLabel: String {
        switch self {
        case .contains: String(localized: "contains", comment: "Custom filter operator")
        case .notContains: String(localized: "does not contain", comment: "Custom filter operator")
        case .equal: String(localized: "is", comment: "Custom filter operator")
        case .notEqual: String(localized: "is not", comment: "Custom filter operator")
        case .greaterThan: String(localized: "is above", comment: "Custom filter operator")
        case .greaterThanOrEqual: String(localized: "is at least", comment: "Custom filter operator")
        case .lessThan: String(localized: "is below", comment: "Custom filter operator")
        case .lessThanOrEqual: String(localized: "is at most", comment: "Custom filter operator")
        case .startsWith: String(localized: "starts with", comment: "Custom filter operator")
        case .notStartsWith: String(localized: "does not start with", comment: "Custom filter operator")
        case .endsWith: String(localized: "ends with", comment: "Custom filter operator")
        case .notEndsWith: String(localized: "does not end with", comment: "Custom filter operator")
        case .inLast: String(localized: "in the last", comment: "Custom filter operator")
        case .notInLast: String(localized: "not in the last", comment: "Custom filter operator")
        case .inNext: String(localized: "in the next", comment: "Custom filter operator")
        case .notInNext: String(localized: "not in the next", comment: "Custom filter operator")
        }
    }

    /// `>`, `>=`, `<` and `<=`, where a second value is meaningless.
    var isComparison: Bool {
        switch self {
        case .greaterThan, .greaterThanOrEqual, .lessThan, .lessThanOrEqual: true
        default: false
        }
    }
}

extension CustomFilterFieldGroup {
    var label: String {
        switch self {
        case .status: String(localized: "Status", comment: "Custom filter field section")
        case .library: String(localized: "Library", comment: "Custom filter field section")
        case .dates: String(localized: "Dates", comment: "Custom filter field section")
        case .ratings: String(localized: "Ratings", comment: "Custom filter field section")
        case .metadata: String(localized: "Metadata", comment: "Custom filter field section")
        }
    }
}

extension CustomFilterTimeUnit {
    var label: String {
        switch self {
        case .seconds: String(localized: "Seconds")
        case .minutes: String(localized: "Minutes")
        case .hours: String(localized: "Hours")
        case .days: String(localized: "Days")
        case .weeks: String(localized: "Weeks")
        case .months: String(localized: "Months")
        }
    }
}

extension CustomFilterField {
    /// The value the web UI's builder starts with for this field and operator.
    func defaultValue(for op: CustomFilterOperator) -> CustomFilterValue {
        guard kind == .date else { return .array([]) }

        return op.isRelativeDate
            ? .object(["time": .string(CustomFilterTimeUnit.days.rawValue), "value": .null])
            : .string(CustomFilterDate.string(from: .now))
    }
}

extension CustomFilterValue {
    /// Whether the builder has no value yet: an empty array or string, or a relative date without an amount.
    var isEmptyValue: Bool {
        switch self {
        case .null: true
        case .array(let values): values.isEmpty
        case .string(let value): value.trimmed().isEmpty
        case .object(let object): object["value"] == nil || object["value"] == .null
        default: false
        }
    }

    var arrayValues: [CustomFilterValue] {
        switch self {
        case .array(let values): values
        case .null: []
        default: [self]
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let value): value
        case .double(let value): Int(exactly: value.rounded())
        default: nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value): Double(value)
        case .double(let value): value
        default: nil
        }
    }

    /// Strings as they are, anything else as raw JSON-like text.
    var rawText: String {
        if case .string(let string) = self { return string }
        return displayString
    }

    /// The value as raw JSON-like text, for conditions Ruddarr can't edit.
    var displayString: String {
        switch self {
        case .null: "null"
        case .bool(let value): value ? "true" : "false"
        case .int(let value): String(value)
        case .double(let value): value.formatted(.number.grouping(.never))
        case .string(let value): "\"\(value)\""
        case .array(let values): "[" + values.map(\.displayString).joined(separator: ", ") + "]"
        case .object(let values):
            "{" + values.sorted { $0.key < $1.key }
                .map { "\"\($0.key)\": \($0.value.displayString)" }
                .joined(separator: ", ") + "}"
        }
    }
}

/// Date-only `"yyyy-mm-dd"` strings in the local calendar, as the web UI's date input stores them.
enum CustomFilterDate {
    static func string(from date: Date) -> String {
        let components = Calendar.gregorian(in: .current).dateComponents([.year, .month, .day], from: date)

        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func date(from string: String) -> Date? {
        CustomFilterValue.string(string).localMidnight(in: .gregorian(in: .current))
    }
}

/// The units a size can be entered in, 1024-based like the web UI.
enum CustomFilterByteUnit: Int, CaseIterable, Identifiable {
    case megabytes = 2
    case gigabytes = 3
    case terabytes = 4

    var id: Self { self }

    var multiplier: Double {
        pow(1_024, Double(rawValue))
    }

    var label: String {
        switch self {
        case .megabytes: "MB"
        case .gigabytes: "GB"
        case .terabytes: "TB"
        }
    }

    /// The largest unit `bytes` is at least one of.
    static func unit(for bytes: Double) -> Self {
        allCases.last { bytes >= $0.multiplier } ?? .megabytes
    }
}

extension [Tag] {
    /// The tags sorted by label.
    var sortedByLabel: [Tag] {
        sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    /// The label of the tag with `id`, if there is one.
    func label(for id: Int?) -> String? {
        first { $0.id == id }?.label
    }
}

extension View {
    /// The title of a custom filters sheet, except on macOS, where it leaks into the main window's toolbar.
    func customFilterSheetTitle(_ title: LocalizedStringKey) -> some View {
        #if os(macOS)
            self
        #else
            navigationTitle(title)
        #endif
    }
}
