import SwiftUI

/// Creates or edits a custom filter with the web UI's condition builder.
struct CustomFilterEditor<Item: CustomFilterable>: View {
    let context: CustomFilterContext<Item>
    let original: CustomFilter
    let isNew: Bool
    let onSave: (CustomFilter) -> Void

    @State private var label: String
    @State private var rows: [CustomFilterConditionRow]
    @State private var onServer: Bool
    @State private var isConfirmingMove = false

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    init(
        context: CustomFilterContext<Item>,
        filter: CustomFilter,
        isNew: Bool,
        onSave: @escaping (CustomFilter) -> Void
    ) {
        self.context = context
        self.original = filter
        self.isNew = isNew
        self.onSave = onSave

        self._label = State(initialValue: filter.label)
        self._onServer = State(initialValue: filter.isOnServer)
        self._rows = State(initialValue: filter.conditions.map { condition in
            CustomFilterConditionRow(
                condition: condition,
                isEditable: condition.isSupported(for: Item.self) && Self.field(for: condition) != nil
            )
        })
    }

    var filters: CustomFilters { context.filters }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $label, prompt: Text("Filter Name"))
                        .labelsHidden()
                }

                ForEach($rows) { $row in
                    conditionSection($row)
                }

                CustomFilterEditorAddSection(items: context.items, filter: filter, onAdd: addCondition)

                CustomFilterEditorStorageSection(
                    serverName: context.serverName,
                    onServer: $onServer,
                    isMovingToDevice: isMovingToDevice
                )
            }
            .formStyle(.grouped)
            .customFilterSheetTitle(isNew ? "New Filter" : "Edit Filter")
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .horizontalToolbarOnly()
            .sensoryAlert(isPresented: filters.alertBinding, error: filters.error) { _ in
                Button("OK") { filters.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .confirmationDialog(
                String(localized: "Remove \"\(original.label)\" from \(context.serverName)?"),
                isPresented: $isConfirmingMove,
                titleVisibility: .visible
            ) {
                Button("Remove from \(context.serverName)", role: .destructive) {
                    Task { await save() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("It will disappear from the web interface and other devices.")
            }
            .tint(settings.theme.tint)
        }
    }

    @ViewBuilder
    func conditionSection(_ row: Binding<CustomFilterConditionRow>) -> some View {
        if row.wrappedValue.isEditable, let field = Self.field(for: row.wrappedValue.condition) {
            CustomFilterConditionSection(
                context: context,
                field: field,
                condition: row.condition,
                onDelete: { removeRow(row.wrappedValue.id) }
            )
        } else {
            CustomFilterUnsupportedSection(
                condition: row.wrappedValue.condition,
                onDelete: { removeRow(row.wrappedValue.id) }
            )
        }
    }

    var isMovingToDevice: Bool {
        original.isOnServer && !isNew && !onServer
    }

    /// The filter as currently edited.
    var filter: CustomFilter {
        CustomFilter(id: original.id, label: label.trimmed(), conditions: rows.map(\.condition))
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark") {
                dismiss()
            }
            .tint(.primary)
            .hideIconOnMac()
        }

        #if os(macOS)
            ToolbarItem(placement: .confirmationAction) {
                saveButton
                    .buttonStyle(.borderedProminent)
            }
        #else
            ToolbarItem(placement: .primaryAction) {
                saveButton
                    .prominentGlassButtonStyle(canSave)
            }
        #endif
    }

    var saveButton: some View {
        Button {
            if isMovingToDevice {
                isConfirmingMove = true
            } else {
                Task { await save() }
            }
        } label: {
            if filters.isWorking {
                ButtonProgressView()
            } else {
                Label("Save", systemImage: "checkmark")
                    .hideIconOnMac()
            }
        }
        .disabled(!canSave)
    }

    var canSave: Bool {
        !label.trimmed().isEmpty && !rows.isEmpty && !filters.isWorking && !hasEmptyCondition
    }

    /// Whether an editable condition has no value yet. Read-only conditions are saved back as they are.
    var hasEmptyCondition: Bool {
        rows.contains { $0.isEditable && $0.condition.value.isEmptyValue }
    }

    static func field(for condition: CustomFilterCondition) -> CustomFilterField? {
        guard let field = Item.customFilterFields.first(where: { $0.key == condition.key }),
              let op = condition.operator,
              field.builder.operators.contains(op)
        else { return nil }

        return field
    }

    func addCondition(_ field: CustomFilterField) {
        guard let op = field.builder.operators.first else { return }

        rows.append(CustomFilterConditionRow(
            condition: CustomFilterCondition(key: field.key, value: field.defaultValue(for: op), operator: op),
            isEditable: true
        ))
    }

    func removeRow(_ id: UUID) {
        rows.removeAll { $0.id == id }
    }

    func save() async {
        guard let saved = await filters.save(filter, onServer: onServer) else { return }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        onSave(saved)
        dismiss()
    }
}

struct CustomFilterConditionRow: Identifiable {
    let id = UUID()
    var condition: CustomFilterCondition
    /// `false` for conditions Ruddarr can't edit or check, which are saved back untouched.
    let isEditable: Bool
}

/// A condition Ruddarr can't check, shown read-only and saved back untouched.
struct CustomFilterUnsupportedSection: View {
    let condition: CustomFilterCondition
    let onDelete: () -> Void

    var body: some View {
        Section {
            LabeledContent("Field") { Text(verbatim: condition.key).textSelection(.enabled) }
            LabeledContent("Operator") { Text(verbatim: condition.type).textSelection(.enabled) }
            LabeledContent("Value") {
                Text(verbatim: condition.value.displayString)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            CustomFilterConditionHeader(summary: condition.rawSummary, onDelete: onDelete)
        } footer: {
            Text("\(Ruddarr.name) can't check this condition. It is kept when saving the filter.")
        }
    }
}
