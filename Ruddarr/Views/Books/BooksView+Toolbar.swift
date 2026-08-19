import SwiftUI
import Sentry

extension BooksView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: BooksPath.search()) {
                    Image(systemName: "plus")
                }
                .tint(.primary)
                .keyboardShortcut("n", modifiers: .command)
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
            Section {
                Picker("Format", selection: $sort.mediaType) {
                    ForEach(BookSort.BookMediaType.allCases) { type in
                        type.label
                    }
                }
                .pickerStyle(.inline)
            }

            Picker("Filter", selection: $sort.filter) {
                ForEach(BookSort.Filter.allCases) { filter in
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
                ForEach(BookSort.Option.allCases) { option in
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
            @Bindable var settings = settings

            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Picker(selection: $settings.chaptarrInstanceId, label: Text("Instances")) {
                        ForEach(settings.chaptarrInstances) { instance in
                            Text(instance.label).tag(Optional.some(instance.id))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack {
                        Image(systemName: "internaldrive")
                        Text(settings.chaptarrInstance?.label ?? "Instance")
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
                Picker(selection: $settings.chaptarrInstanceId, label: Text("Instances")) {
                    ForEach(settings.chaptarrInstances) { instance in
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
            guard let newInstanceId = settings.chaptarrInstanceId else {
                leaveBreadcrumb(.fatal, category: "books", message: "Missing Chaptarr instance id")

                return
            }

            guard let newInstance = settings.instanceById(newInstanceId) else {
                leaveBreadcrumb(.fatal, category: "books", message: "Chaptarr instance not found")

                return
            }

            instance.switchTo(newInstance)

            await fetchBooksWithAlert()
        }
    }
}
