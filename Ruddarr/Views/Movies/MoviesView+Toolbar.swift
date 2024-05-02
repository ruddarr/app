import SwiftUI

extension MoviesView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Path.search()) {
                    Image(systemName: "plus")
                }.id(UUID())
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarViewOptions: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack {
                toolbarFilterButton
                toolbarSortingButton
            }.id(UUID())
        }
    }

    var toolbarFilterButton: some View {
        Menu("Filter", systemImage: "line.3.horizontal.decrease") {
            Picker(selection: $sort.filter, label: Text("Filter")) {
                ForEach(MovieSort.Filter.allCases) { filter in
                    filter.label
                }
            }
            .pickerStyle(.inline)
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
            .onChange(of: sort.option) {
                switch sort.option {
                case .byTitle:
                    sort.isAscending = true
                default:
                    sort.isAscending = false
                }
            }

            Section {
                Picker("Direction", selection: $sort.isAscending) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }

    @ToolbarContentBuilder
    var toolbarInstancePicker: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Menu {
                Picker(selection: $settings.radarrInstanceId, label: Text("Instances")) {
                    ForEach(settings.radarrInstances) { instance in
                        Text(instance.label).tag(Optional.some(instance.id))
                    }
                }
                .onChange(of: settings.radarrInstanceId, changeInstance)
                .pickerStyle(.inline)
            } label: {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(settings.radarrInstance?.label ?? "Instance")
                        .fontWeight(.semibold)
                        .tint(.primary)

                    Image(systemName: "chevron.down")
                        .symbolVariant(.circle.fill)
                        .foregroundStyle(.secondary, Color(UIColor.secondarySystemFill))
                        .font(.system(size: 13, weight: .bold))
                }.tint(.primary)
            }
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
