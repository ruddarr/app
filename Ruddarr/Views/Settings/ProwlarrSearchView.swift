import SwiftUI

struct ProwlarrSearchView: View {
    let instance: Instance
    @State var search: ProwlarrSearch
    @State private var selectedRelease: ProwlarrRelease?
    @State private var currentTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    @AppStorage("prowlarrSearchSort", store: dependencies.store) private var sort: ProwlarrSearchSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    init(instance: Instance) {
        self.instance = instance
        self._search = State(wrappedValue: ProwlarrSearch(instance))
    }

    var displayed: [ProwlarrRelease] {
        sort.filterAndSortItems(search.items)
    }

    var body: some View {
        @Bindable var search = search

        List {
            ForEach(displayed) { release in
                Button {
                    searchFocused = false
                    selectedRelease = release
                } label: {
                    ProwlarrSearchRow(release: release)
                        .environmentObject(settings)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.inset)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Search Indexers")
        .safeNavigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $search.query,
            placement: .drawerOrToolbar(.always),
            prompt: Text("Search Prowlarr")
        )
        .searchFocused($searchFocused)
        // Keep sort/filter buttons reachable while the search field is focused;
        // otherwise dismissing the field (via X) would clear an active query.
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .task {
            if settings.releaseFilters == .reset { sort = .init() }
        }
        .onSubmit(of: .search) { startSearch() }
        .onChange(of: search.category) { _, _ in
            if !search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                startSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { sortButton }
            ToolbarItem(placement: .primaryAction) { filterButton }
        }
        .alert(
            isPresented: search.errorBinding,
            error: search.error
        ) { _ in
            Button("OK") { search.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .overlay {
            if search.isSearching {
                SearchingIndicator()
            } else if !search.hasSearched {
                emptyState
            } else if search.items.isEmpty {
                noResults
            } else if displayed.isEmpty {
                noMatching
            }
        }
        .sheet(item: $selectedRelease) { release in
            ProwlarrSearchSheet(release: release, search: search)
                .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
                .presentationBackground(.sheetBackground)
                .environmentObject(settings)
        }
    }

    var sortButton: some View {
        Menu {
            Section {
                Picker("Sort By", selection: $sort.option) {
                    ForEach(ProwlarrSearchSort.Option.allCases) { option in
                        option.label.tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            if sort.option != .byRelevance {
                Section {
                    Picker("Direction", selection: $sort.isAscending) {
                        Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                        Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                    }.pickerStyle(.inline)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
        .tint(.primary)
        .menuIndicator(.hidden)
    }

    var filterButton: some View {
        Menu {
            categoryPicker

            if search.protocols.count > 1 {
                protocolPicker
            }

            if search.indexers.count > 1 {
                indexerPicker
            }
        } label: {
            if sort.hasFilter || search.category != .all {
                Image("filters.badge")
                    .offset(y: 3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.tint, .primary)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
        .menuIndicator(.hidden)
    }

    var categoryPicker: some View {
        Menu {
            Picker("Category", selection: $search.category) {
                ForEach(ProwlarrSearchCategory.allCases) { category in
                    Text(category.label).tag(category)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                search.category == .all ? String(localized: "Category") : search.category.label,
                systemImage: "tag"
            )
        }
    }

    var protocolPicker: some View {
        Menu {
            Picker("Protocol", selection: $sort.network) {
                Text("Any Protocol").tag(String.all)

                ForEach(search.protocols, id: \.self) { type in
                    Text(type).tag(Optional.some(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.network == .all ? String(localized: "Protocol") : sort.network,
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
    }

    var indexerPicker: some View {
        Menu {
            Picker("Indexer", selection: $sort.indexer) {
                Text("Any Indexer").tag(String.all)

                ForEach(search.indexers, id: \.self) { indexer in
                    Text(indexer).tag(Optional.some(indexer))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.indexer == .all ? String(localized: "Indexer") : sort.indexer,
                systemImage: "building.2"
            )
        }
    }

    var emptyState: some View {
        ContentUnavailableView(
            "Search Prowlarr",
            systemImage: "magnifyingglass",
            description: Text("Search across your enabled Prowlarr indexers. Grabs are sent to Prowlarr's download client and won't appear in Ruddarr's Activity.")
        )
    }

    var noResults: some View {
        ContentUnavailableView(
            "No Releases Match",
            systemImage: "slash.circle",
            description: Text("No releases match \"\(search.query.trimmingCharacters(in: .whitespacesAndNewlines))\".")
        )
    }

    var noMatching: some View {
        ContentUnavailableView {
            Label("No Releases Match", systemImage: "slash.circle")
        } description: {
            Text("No releases match the selected filters.")
        } actions: {
            Button("Clear Filters") {
                sort.resetFilters()
            }
        }
    }

    func startSearch() {
        currentTask?.cancel()
        currentTask = Task {
            await search.search()
        }
    }
}

#Preview {
    NavigationStack {
        ProwlarrSearchView(instance: .prowlarrDummy)
    }
    .withAppState()
}
