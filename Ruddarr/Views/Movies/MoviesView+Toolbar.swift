import SwiftUI

extension MoviesView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: MoviesPath.search()) {
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
                .menuIndicator(.hidden)
        }

        ToolbarItem(placement: .navigation) {
            toolbarSortingButton
                .menuIndicator(.hidden)
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            Picker(selection: $sort.filter, label: Text("Filter")) {
                ForEach(MovieSort.Filter.allCases) { filter in
                    filter.label
                }
            }
            .pickerStyle(.inline)
        } label: {
            if sort.filter != .all {
                Image("filters.badge")
                    .offset(y: 3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.tint, .primary)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Picker(selection: $sort.option, label: Text("Sort By")) {
                ForEach(MovieSort.Option.allCases) { option in
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
                    Picker(selection: $settings.radarrInstanceId, label: Text("Instances")) {
                        ForEach(settings.radarrInstances) { instance in
                            Text(instance.label).tag(Optional.some(instance.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack {
                        Image(systemName: "internaldrive")
                        Text(settings.radarrInstance?.label ?? "Instance")
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
            guard let newInstanceId = settings.radarrInstanceId else {
                leaveBreadcrumb(.fatal, category: "movies", message: "Missing Radarr instance id")

                return
            }

            guard let newInstance = settings.instanceById(newInstanceId) else {
                leaveBreadcrumb(.fatal, category: "movies", message: "Radarr instance not found")

                return
            }

            instance.switchTo(newInstance)

            await fetchMoviesWithAlert()

            if let model = await instance.fetchMetadata() {
                settings.saveInstance(model)
            }
        }
    }
}
