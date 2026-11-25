import SwiftUI
import Sentry

extension SeriesView {
    var searchPlacement: SearchFieldPlacement {
        #if os(iOS)
            deviceType == .phone ? .navigationBarDrawer : .automatic
        #else
            .automatic
        #endif
    }

    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: SeriesPath.search()) {
                    Label("Add Series", systemImage: "plus")
                }
                .tint(.primary)
                .keyboardShortcut("n", modifiers: .command)
            }
            .priority(.high)
        }
    }

    @ToolbarContentBuilder
    var toolbarViewOptions: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            toolbarFilterButton
                .menuIndicator(.hidden)
        }

        ToolbarItem(placement: .navigation) {
            toolbarSortingButton
                .menuIndicator(.hidden)
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            Picker("Filter", selection: $sort.filter) {
                ForEach(SeriesSort.Filter.allCases) { filter in
                    filter.label
                }
            }
            .pickerStyle(.inline)

            Picker(selection: $sort.folder) {
                Text("Any Folder").tag(String.all)

                ForEach(instance.rootFolders) { folder in
                    Text(folder.menuLabel(among: instance.rootFolders)).tag(folder.path ?? "")
                }
            } label: {
                if let folder = instance.rootFolders.first(where: { $0.path == sort.folder }) {
                    Label(folder.menuLabel(among: instance.rootFolders), systemImage: "folder")
                } else {
                    Label("Root Folder", systemImage: "folder")
                }
            }.pickerStyle(.menu)

            // Until the server's filters load, the saved one is listed so it can be turned off.
            let filters = instance.customFilters ?? [sort.customFilter].compactMap { $0 }

            if !filters.isEmpty {
                Picker(selection: $sort.customFilter) {
                    Text("None").tag(CustomFilter?.none)

                    ForEach(filters) { filter in
                        Text(filter.label).tag(Optional(filter))
                    }
                } label: {
                    Label(sort.customFilter?.label ?? String(localized: "Custom Filter"), systemImage: "line.3.horizontal.decrease.circle")
                }.pickerStyle(.menu)
            }
        } label: {
            ToolbarFilterLabel(
                active: sort.filter != .all || sort.folder != .all || sort.customFilter != nil,
                tint: settings.theme.tint
            )
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Picker(selection: $sort.option, label: Text("Sort By")) {
                ForEach(SeriesSort.Option.allCases) { option in
                    option.label
                }
            }
            .pickerStyle(.inline)

            Section {
                Picker("Direction", selection: $sort.isAscending) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }.pickerStyle(.inline)
            }
        } label: {
            ToolbarIconLabel(title: Text("Sort By"), systemImage: "arrow.up.arrow.down")
        }
    }

    @ToolbarContentBuilder
    var bottomBarInstancePicker: some ToolbarContent {
        #if os(iOS)
            @Bindable var settings = settings

            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Picker(selection: $settings.sonarrInstanceId, label: Text("Instances")) {
                        ForEach(settings.sonarrInstances) { instance in
                            Text(instance.label).tag(Optional.some(instance.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack {
                        Image(systemName: "internaldrive")
                        Text(settings.sonarrInstance?.label ?? "Instance")
                            .fontWeight(.medium)
                    }
                }
                .tint(.primary)
            }
        #else
            ToolbarSpacer(.flexible, placement: .principal)
        #endif
    }

    @ToolbarContentBuilder
    var toolbarInstancePicker: some ToolbarContent {
        @Bindable var settings = settings

        ToolbarSpacer(.fixed, placement: .navigation)

        ToolbarItem(placement: .navigation) {
            Menu {
                Picker(selection: $settings.sonarrInstanceId, label: Text("Instances")) {
                    ForEach(settings.sonarrInstances) { instance in
                        Text(instance.label).tag(Optional.some(instance.id))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                ToolbarIconLabel(
                    title: Text(settings.sonarrInstance?.label ?? String(localized: "Instance")),
                    systemImage: "internaldrive"
                )
            }
            .tint(.primary)
        }
    }

    func changeInstance() {
        Task { @MainActor in
            guard let newInstanceId = settings.sonarrInstanceId else {
                leaveBreadcrumb(.fatal, category: "series", message: "Missing Sonarr instance id")

                return
            }

            guard let newInstance = settings.instanceById(newInstanceId) else {
                leaveBreadcrumb(.fatal, category: "series", message: "Sonarr instance not found")

                return
            }

            instance.switchTo(newInstance)
            // Filter ids are per server.
            sort.customFilter = nil

            await fetchSeriesWithAlert()

            if let model = await instance.fetchMetadata() {
                settings.saveInstanceMetadata(model)
            }
        }
    }

    /// Keeps the selected custom filter in step with the server's copy, and clears it once it's gone.
    func updateCustomFilter() {
        guard let filters = instance.customFilters, let selected = sort.customFilter else { return }
        sort.customFilter = filters.first { $0.id == selected.id }
    }
}
