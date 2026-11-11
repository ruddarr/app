import SwiftUI

extension CustomFilterOption {
    /// The choices of a `.bool` field.
    static var yesNo: [CustomFilterOption] {
        [
            CustomFilterOption(value: .bool(true), label: String(localized: "Yes")),
            CustomFilterOption(value: .bool(false), label: String(localized: "No")),
        ]
    }
}

extension [CustomFilterOption] {
    /// The labels of `values`, in their order. A value without an option shows as its raw text.
    func labels(of values: [CustomFilterValue]) -> [String] {
        values.map { value in first { $0.value == value }?.label ?? value.rawText }
    }
}

extension CustomFilterContext {
    /// The options of `field`, plus any values of `value` that aren't among them.
    func options(for field: CustomFilterField, including value: CustomFilterValue) -> [CustomFilterOption] {
        var options: [CustomFilterOption] = switch field.kind {
        case .bool:
            CustomFilterOption.yesNo
        case .options(let options):
            options
        case .tag:
            tags.sortedByLabel
                .map { CustomFilterOption(value: .int($0.id), label: $0.label) }
        case .qualityProfile:
            qualityProfiles
                .map { CustomFilterOption(value: .int($0.id), label: $0.name) }
        case .libraryValues:
            Item.libraryValues(for: field.key, in: items)
                .map { CustomFilterOption(value: .string($0), label: $0) }
        default:
            []
        }

        for value in value.arrayValues where !options.contains(where: { $0.value == value }) {
            options.append(CustomFilterOption(value: value, label: value.rawText))
        }

        return options
    }

    /// The condition as a sentence, such as "Quality Profile is Ultra-HD (4K)" or "Added in the last 30 days".
    func summary(of condition: CustomFilterCondition, field: CustomFilterField) -> String {
        let op = condition.operator ?? field.builder.operators[0]
        let value = condition.value.isEmptyValue ? "…" : valueSummary(of: condition.value, field: field, operator: op)

        return "\(field.label) \(op.label(for: field.builder)) \(value)"
    }

    private func valueSummary(of value: CustomFilterValue, field: CustomFilterField, operator op: CustomFilterOperator) -> String {
        switch field.kind {
        case .date:
            return Self.dateSummary(of: value, isRelative: op.isRelativeDate)
        case .bool, .options, .tag, .qualityProfile:
            return options(for: field, including: value)
                .labels(of: value.arrayValues)
                .formatted(.list(type: .or))
        case .number:
            return value.arrayValues
                .map { $0.doubleValue?.formatted() ?? $0.rawText }
                .formatted(.list(type: .or))
        case .bytes:
            return value.arrayValues
                .map { $0.doubleValue.map { formatBytes(Float($0)) } ?? $0.rawText }
                .formatted(.list(type: .or))
        case .text, .libraryValues:
            return value.arrayValues.map(\.rawText).formatted(.list(type: .or))
        }
    }

    private static func dateSummary(of value: CustomFilterValue, isRelative: Bool) -> String {
        if isRelative {
            guard let relative = CustomFilterRelativeDate(value) else { return value.displayString }
            return relative.formatted
        }

        guard case .string(let string) = value, let date = CustomFilterDate.date(from: string) else {
            return value.rawText
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

extension CustomFilterCondition {
    /// A raw but readable sentence for a condition Ruddarr can't edit, such as "keywords contains heist".
    var rawSummary: String {
        let op = self.operator?.label(for: .string) ?? type
        let values = value.arrayValues

        let value = values.isEmpty
            ? "…"
            : values.map { $0.isScalarDisplay ? $0.rawText : $0.displayString }.formatted(.list(type: .or))

        return "\(key) \(op) \(value)"
    }
}

private extension CustomFilterValue {
    var isScalarDisplay: Bool {
        switch self {
        case .array, .object: false
        default: true
        }
    }
}

private extension CustomFilterRelativeDate {
    /// "30 days", "1 month".
    var formatted: String {
        let amount = Int(amount.rounded())
        var components = DateComponents()
        let allowed: NSCalendar.Unit

        // Only the condition's own unit, so 30 days stays "30 days" rather than "4 weeks, 2 days".
        switch unit {
        case .seconds: components.second = amount; allowed = .second
        case .minutes: components.minute = amount; allowed = .minute
        case .hours: components.hour = amount; allowed = .hour
        case .days: components.day = amount; allowed = .day
        case .weeks: components.weekOfMonth = amount; allowed = .weekOfMonth
        case .months: components.month = amount; allowed = .month
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = allowed
        formatter.zeroFormattingBehavior = .default

        return formatter.string(from: components) ?? "\(amount)"
    }
}
