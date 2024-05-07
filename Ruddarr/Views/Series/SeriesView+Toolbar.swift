import SwiftUI

extension SeriesView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: SeriesPath.search()) {
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
                ForEach(SeriesSort.Filter.allCases) { filter in
                    filter.label
                }
            }
            .pickerStyle(.inline)
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
                Picker(selection: $settings.sonarrInstanceId, label: Text("Instances")) {
                    ForEach(settings.sonarrInstances) { instance in
                        Text(instance.label).tag(Optional.some(instance.id))
                    }
                }
                .onChange(of: settings.sonarrInstanceId, changeInstance)
                .pickerStyle(.inline)
            } label: {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(settings.sonarrInstance?.label ?? "Instance")
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
