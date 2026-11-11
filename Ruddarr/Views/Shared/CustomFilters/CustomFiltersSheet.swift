import SwiftUI

/// Lists an instance's custom filters, to create, edit and delete them.
struct CustomFiltersSheet<Item: CustomFilterable>: View {
    let context: CustomFilterContext<Item>
    @Binding var selection: CustomFilter.ID?

    @State private var editing: EditRequest?
    @State private var filterToDelete: CustomFilter?

    @Environment(AppSettings.self) private var settings
    @Environment(\.deviceType) private var deviceType
    @Environment(\.dismiss) private var dismiss

    struct EditRequest: Identifiable {
        let id = UUID()
        let filter: CustomFilter
        let isNew: Bool
        /// Captured up front: while saving, the old id can disappear from `all` and clear the selection.
        let selectAfterSaving: Bool
    }

    var filters: CustomFilters { context.filters }

    /// The editor shows its own errors while it's open.
    var alertBinding: Binding<Bool> {
        .init(get: { filters.error != nil && editing == nil }, set: { _ in })
    }

    var body: some View {
        NavigationStack {
            list
                .sheet(item: $editing, content: editor)
                .confirmationDialog(
                    "Delete Filter?",
                    isPresented: Binding(get: { filterToDelete != nil }, set: { if !$0 { filterToDelete = nil } }),
                    titleVisibility: .visible,
                    presenting: filterToDelete
                ) { filter in
                    Button("Delete", role: .destructive) {
                        Task { await delete(filter) }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { _ in
                    Text("This filter will also be removed from the \(context.serverName) web interface.")
                }
                .sensoryAlert(isPresented: alertBinding, error: filters.error) { _ in
                    Button("OK") { filters.error = nil }
                } message: { error in
                    Text(error.recoverySuggestionFallback)
                }
                .tint(settings.theme.tint)
        }
    }

    var list: some View {
        List {
            serverSection
            deviceSection
        }
        .customFilterSheetTitle("Custom Filters")
        .safeNavigationBarTitleDisplayMode(.inline)
        .overlay {
            if filters.all.isEmpty {
                emptyState
            }
        }
        .refreshable {
            _ = await filters.fetch(reportingErrors: true)
        }
        .toolbar { toolbar }
        .horizontalToolbarOnly()
    }

    func editor(_ request: EditRequest) -> some View {
        CustomFilterEditor(context: context, filter: request.filter, isNew: request.isNew) { saved in
            if request.selectAfterSaving {
                selection = saved.id
            }
        }
        #if os(macOS)
            // The form's ideal height can exceed the window, so cap the sheet's ideal size.
            .frame(minWidth: 520, minHeight: 400, idealHeight: 600)
        #endif
        .pageSized(deviceType == .pad)
        .presentationBackground(.sheetBackground)
    }

    @ViewBuilder
    var serverSection: some View {
        let server = filters.serverFilters

        if !server.isEmpty {
            Section {
                ForEach(server) { row($0) }
            } header: {
                Text(context.serverName)
            } footer: {
                Text("These filters also show in the \(context.serverName) web interface.")
            }
        }
    }

    @ViewBuilder
    var deviceSection: some View {
        let local = filters.appFilters

        if !local.isEmpty {
            Section {
                ForEach(local) { row($0) }
            } header: {
                Text("This Device")
            } footer: {
                Text("These filters are only available in \(Ruddarr.name) on this device.")
            }
        }
    }

    func row(_ filter: CustomFilter) -> some View {
        Button {
            edit(filter)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filter.label)
                        .foregroundStyle(.primary)

                    Text(filter.summary(for: Item.self))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !filter.isSupported(for: Item.self) {
                        Text("\(Ruddarr.name) can't check some of its conditions.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if selection == filter.id {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Selected")
                }

                #if os(macOS)
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                #endif
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: !filter.isOnServer) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                requestDelete(filter)
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") {
                edit(filter)
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                Task { await duplicate(filter) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                requestDelete(filter)
            }
        }
    }

    func edit(_ filter: CustomFilter) {
        editing = EditRequest(filter: filter, isNew: false, selectAfterSaving: selection == filter.id)
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("No Custom Filters", systemImage: "line.3.horizontal.decrease")
        } description: {
            Text("Create a filter here, or in the \(context.serverName) web interface.")
        } actions: {
            Button("New Filter") {
                editing = EditRequest(filter: .new(), isNew: true, selectAfterSaving: true)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") {
                dismiss()
            }
            .tint(.primary)
            .hideIconOnMac()
        }

        // macOS sheets don't show `.primaryAction`, so it goes in the bottom bar's leading slot.
        ToolbarItem(placement: newFilterPlacement) {
            Button("New Filter", systemImage: "plus") {
                editing = EditRequest(filter: .new(), isNew: true, selectAfterSaving: true)
            }
            .tint(.primary)
            .hideIconOnMac()
        }
    }

    var newFilterPlacement: ToolbarItemPlacement {
        #if os(macOS)
            .destructiveAction
        #else
            .primaryAction
        #endif
    }

    /// Server filters also disappear from the web UI, so they're confirmed first.
    func requestDelete(_ filter: CustomFilter) {
        if filter.isOnServer {
            filterToDelete = filter
        } else {
            Task { await delete(filter) }
        }
    }

    /// Saves an on-device copy, which works even when the original is on the server.
    func duplicate(_ filter: CustomFilter) async {
        let copy = CustomFilter(
            id: .app(UUID()),
            label: String(localized: "\(filter.label) Copy", comment: "Name of a duplicated custom filter"),
            conditions: filter.conditions
        )

        _ = await filters.save(copy, onServer: false)
    }

    func delete(_ filter: CustomFilter) async {
        guard await filters.delete(filter) else { return }

        if selection == filter.id {
            selection = nil
        }
    }
}

extension CustomFilter {
    /// A one-line summary, e.g. "3 conditions · Monitored, Quality Profile, Added".
    func summary<Item: CustomFilterable>(for _: Item.Type) -> String {
        let count = conditions.count
        let fields = conditions
            .compactMap { condition in Item.customFilterFields.first { $0.key == condition.key }?.label }
            .reduce(into: [String]()) { labels, label in
                if !labels.contains(label) { labels.append(label) }
            }

        let conditionCount = count == 1
            ? String(localized: "1 condition", comment: "Custom filter summary")
            : String(localized: "\(count) conditions", comment: "Custom filter summary")

        return fields.isEmpty ? conditionCount : "\(conditionCount) · \(fields.joined(separator: ", "))"
    }
}

private extension View {
    /// The editor shows more conditions in a page-sized sheet on iPad.
    @ViewBuilder
    func pageSized(_ condition: Bool) -> some View {
        if condition {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
