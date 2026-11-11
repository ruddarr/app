import SwiftUI

/// One editable condition of the filter editor: field, operator and value.
struct CustomFilterConditionSection<Item: CustomFilterable>: View {
    let context: CustomFilterContext<Item>
    let field: CustomFilterField
    @Binding var condition: CustomFilterCondition
    let onDelete: () -> Void

    /// Fields whose ratings are stored on a 0–100 scale.
    private static var percentRatingKeys: Set<String> { ["tmdbRating", "traktRating", "ratings"] }

    var body: some View {
        Section {
            Picker("Field", selection: fieldBinding) {
                CustomFilterFieldPickerContent(fields: Item.customFilterFields) { field in
                    Text(field.label).tag(field.key)
                }
            }

            Picker("Operator", selection: operatorBinding) {
                ForEach(field.builder.operators) { op in
                    Text(op.label(for: field.builder)).tag(op)
                }
            }

            valueEditor
                .id(field.key)
        } header: {
            CustomFilterConditionHeader(summary: context.summary(of: condition, field: field), onDelete: onDelete)
        } footer: {
            if condition.value.isEmptyValue {
                CustomFilterConditionEmptyHint()
            }
        }
    }

    @ViewBuilder
    var valueEditor: some View {
        switch field.kind {
        case .text, .number, .bytes:
            CustomFilterListValueEditor(
                kind: field.kind,
                allowsMultiple: !(condition.operator?.isComparison ?? false),
                isPercentScale: Self.percentRatingKeys.contains(field.key),
                value: $condition.value
            )
        case .date:
            CustomFilterDateValueEditor(isRelative: condition.operator?.isRelativeDate ?? false, value: $condition.value)
        case .bool:
            CustomFilterBoolValueEditor(value: $condition.value)
        case .options, .tag, .qualityProfile, .libraryValues:
            // `.libraryValues` options scan the whole library, so they're computed once per render.
            let options = context.options(for: field, including: condition.value)

            NavigationLink {
                CustomFilterOptionList(title: field.label, options: options, value: $condition.value)
            } label: {
                LabeledContent("Values") {
                    Text(selectionSummary(options))
                        .lineLimit(1)
                }
            }
        }
    }

    var fieldBinding: Binding<String> {
        Binding(
            get: { condition.key },
            set: { key in
                guard key != condition.key,
                      let newField = Item.customFilterFields.first(where: { $0.key == key }),
                      let op = newField.builder.operators.first
                else { return }

                condition = CustomFilterCondition(key: key, value: newField.defaultValue(for: op), operator: op)
            }
        )
    }

    var operatorBinding: Binding<CustomFilterOperator> {
        Binding(
            get: { condition.operator ?? field.builder.operators[0] },
            set: { op in
                let previous = condition.operator
                condition.type = op.rawValue

                if field.kind == .date, previous?.isRelativeDate != op.isRelativeDate {
                    condition.value = field.defaultValue(for: op)
                }
            }
        )
    }

    func selectionSummary(_ options: [CustomFilterOption]) -> String {
        let selected = condition.value.arrayValues
        guard !selected.isEmpty else { return String(localized: "None") }

        return options.labels(of: selected).formatted(.list(type: .or))
    }
}

/// The builder's fields, in sections (Status, Library, …), for a `Picker` or `Menu`.
struct CustomFilterFieldPickerContent<Row: View>: View {
    let fields: [CustomFilterField]
    @ViewBuilder let row: (CustomFilterField) -> Row

    var body: some View {
        ForEach(CustomFilterFieldGroup.allCases) { group in
            let fields = fields.filter { $0.group == group }

            if !fields.isEmpty {
                Section(group.label) {
                    ForEach(fields) { field in
                        row(field)
                    }
                }
            }
        }
    }
}

/// A single Yes/No choice, stored as `[true]` or `[false]`.
struct CustomFilterBoolValueEditor: View {
    @Binding var value: CustomFilterValue

    var body: some View {
        Picker("Value", selection: selection) {
            // A stored value with both or neither shows as unset until the user picks one.
            if selection.wrappedValue == nil {
                Text("Choose").tag(Bool?.none)
            }

            ForEach(CustomFilterOption.yesNo) { option in
                if case .bool(let bool) = option.value {
                    Text(option.label).tag(Bool?.some(bool))
                }
            }
        }
    }

    var selection: Binding<Bool?> {
        Binding(
            get: {
                let values = value.arrayValues
                guard values.count == 1, case .bool(let bool) = values[0] else { return nil }
                return bool
            },
            set: { bool in
                value = bool.map { .array([.bool($0)]) } ?? .array([])
            }
        )
    }
}

/// A searchable list of options with checkmarks, for tags, quality profiles and library values.
struct CustomFilterOptionList: View {
    let title: String
    let options: [CustomFilterOption]
    @Binding var value: CustomFilterValue

    @State private var query = ""

    var body: some View {
        Form {
            Section {
                ForEach(filteredOptions) { option in
                    CustomFilterCheckmarkRow(
                        label: option.label,
                        isSelected: value.arrayValues.contains(option.value)
                    ) {
                        value = Self.toggle(option.value, in: value)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        .safeNavigationBarTitleDisplayMode(.inline)
        .overlay {
            if options.isEmpty {
                ContentUnavailableView("No Values", systemImage: "list.bullet")
            }
        }
        .modifier(SearchableIfLong(query: $query, isLong: options.count > 12))
    }

    static func toggle(_ option: CustomFilterValue, in value: CustomFilterValue) -> CustomFilterValue {
        var selected = value.arrayValues

        if let index = selected.firstIndex(of: option) {
            selected.remove(at: index)
        } else {
            selected.append(option)
        }

        return .array(selected)
    }

    var filteredOptions: [CustomFilterOption] {
        let query = query.trimmed()
        guard !query.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(query) }
    }
}

private struct SearchableIfLong: ViewModifier {
    @Binding var query: String
    let isLong: Bool

    func body(content: Content) -> some View {
        if isLong {
            content.searchable(text: $query)
        } else {
            content
        }
    }
}

struct CustomFilterCheckmarkRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
