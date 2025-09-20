import SwiftUI

extension SeriesView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: SeriesPath.search()) {
                    Image(systemName: "plus")
                }
                .tint(.primary)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarViewOptions: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            toolbarFilterButton
                .tint(.primary)
                .menuIndicator(.hidden)
        }

        ToolbarItem(placement: .navigation) {
            toolbarSortingButton
                .tint(.primary)
                .menuIndicator(.hidden)
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            Picker(selection: $sort.filter, label: Text("Filter")) {
                ForEach(SeriesSort.Filter.allCases) { filter in
                    filter.label
                }
            }
            .pickerStyle(.inline)
        } label: {
            if sort.filter != .all {
                Image("filters.badge").offset(y: 3.2)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
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
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }

    @ToolbarContentBuilder
    var bottomBarInstancePicker: some ToolbarContent {
        #if os(iOS)
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
                Image(systemName: "internaldrive")
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

            await fetchSeriesWithAlert()

            if let model = await instance.fetchMetadata() {
                settings.saveInstance(model)
            }
        }
    }
}
