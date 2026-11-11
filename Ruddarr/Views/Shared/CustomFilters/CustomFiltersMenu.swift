import SwiftUI

/// The Tag picker of the Movies and Series filter menus.
struct TagFilterPicker: View {
    let tags: [Tag]
    @Binding var selection: Int?

    var body: some View {
        if !tags.isEmpty {
            Picker(selection: $selection) {
                Text("Any Tag").tag(Int?.none)

                ForEach(tags.sortedByLabel) { tag in
                    Text(tag.label).tag(Optional(tag.id))
                }
            } label: {
                if let label = tags.label(for: selection) {
                    Label(label, systemImage: "tag")
                } else {
                    Label("Tag", systemImage: "tag")
                }
            }
            .pickerStyle(.menu)
        }
    }
}

/// The Custom Filters sections of the Movies and Series filter menus.
struct CustomFiltersMenuSection<Item: CustomFilterable>: View {
    let filters: CustomFilters
    /// "Radarr" or "Sonarr", the header of the server's filters.
    let serverName: String
    @Binding var selection: CustomFilter.ID?
    let manage: () -> Void

    var body: some View {
        let server = filters.serverFilters
        let local = filters.appFilters

        if !server.isEmpty && !local.isEmpty {
            Section(serverName) {
                ForEach(server) { row($0) }
            }

            Section("This Device") {
                ForEach(local) { row($0) }
            }
        } else if !filters.all.isEmpty {
            Section("Custom Filters") {
                ForEach(filters.all) { row($0) }
            }
        }

        Section {
            Button("Manage Filters…", systemImage: "slider.horizontal.3", action: manage)
        }
    }

    @ViewBuilder
    func row(_ filter: CustomFilter) -> some View {
        if filter.isSupported(for: Item.self) {
            Toggle(filter.label, isOn: Binding(
                get: { selection == filter.id },
                set: { selection = $0 ? filter.id : nil }
            ))
        } else {
            // Manage Filters explains why the filter can't be applied.
            Button(filter.label, systemImage: "exclamationmark.triangle", action: manage)
        }
    }
}

extension View {
    /// Presents the Manage Filters sheet. When `filters` change, clears `selection` if its filter is gone, otherwise calls `onChange`.
    func customFiltersSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        selection: Binding<CustomFilter.ID?>,
        in filters: CustomFilters,
        onChange: @escaping () -> Void,
        @ViewBuilder sheet: @escaping () -> Sheet
    ) -> some View {
        self
            .onChange(of: filters.all) {
                if let id = selection.wrappedValue, filters.byId(id) == nil {
                    // Clearing the selection changes the sort, which refreshes the grid.
                    selection.wrappedValue = nil
                    return
                }

                onChange()
            }
            .sheet(isPresented: isPresented) {
                sheet()
                    #if os(macOS)
                        .frame(minWidth: 460, minHeight: 480)
                    #endif
                    .presentationBackground(.sheetBackground)
            }
    }
}
