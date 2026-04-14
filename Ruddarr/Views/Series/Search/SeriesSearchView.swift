import SwiftUI
import Combine

struct SeriesSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = false
    @State private var browseMode: Discovery.BrowseMode = .discover

    @Environment(SonarrInstance.self) private var instance
    @Environment(\.isSearching) private var isSearching

    let searchTextPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var seriesLookup = instance.lookup

        VStack(spacing: 0) {
            if searchQuery.isEmpty && !isSearching {
                Picker(selection: $browseMode, label: EmptyView()) {
                    Text(Discovery.BrowseMode.discover.label).tag(Discovery.BrowseMode.discover)
                    Text(Discovery.BrowseMode.upcoming.label).tag(Discovery.BrowseMode.upcoming)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            ScrollView {
                if seriesLookup.sortedItems.isEmpty && searchQuery.isEmpty {
                    MediaGrid(items: browseItems) { item in
                        DiscoveryGridPoster(item: item)
                    } header: {
                        Text(browseHeader)
                            .padding(.top, 12)
                    }
                    .viewBottomPadding()
                    .scenePadding(.horizontal)
                    .opacity(browseItems.isEmpty ? 0 : 1)
                    .animation(.easeIn, value: browseItems)
                } else {
                    MediaGrid(items: seriesLookup.sortedItems) { series in
                        SeriesSearchItem(series: series)
                            .environment(instance)
                    }
                    .padding(.top, 12)
                    .scenePadding(.horizontal)
                    .viewBottomPadding()
                }
            }
            .id(browseMode)
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("Search")
        .safeNavigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always)
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($seriesLookup.sort) {
            ForEach(SeriesLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .task {
            await discovery.fetch(.series)
            await discovery.fetch(.series, mode: .upcoming)
        }
        .onSubmit(of: .search) {
            searchTextPublisher.send(searchQuery)
        }
        .onChange(of: searchQuery, initial: true, handleSearchQueryChange)
        .onReceive(
            searchTextPublisher.debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
        ) { _ in
            performSearch()
        }
        .alert(
            isPresented: instance.lookup.errorBinding,
            error: instance.lookup.error
        ) { _ in
            Button("OK") { instance.lookup.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .overlay {
            if instance.lookup.isSearching && instance.lookup.isEmpty() {
                Loading()
            } else if instance.lookup.noResults(searchQuery) {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    var browseItems: [DiscoveryItem] {
        switch browseMode {
        case .discover: Discovery.shared.series
        case .upcoming: Discovery.shared.upcomingSeries
        }
    }

    var browseHeader: String {
        switch browseMode {
        case .discover: "Popular This Week"
        case .upcoming: "Coming Soon"
        }
    }

    func performSearch() {
        Task { @MainActor in
            await instance.lookup.search(query: searchQuery)
        }
    }

    func handleSearchQueryChange(oldQuery: String, newQuery: String) {
        if let imdb = extractImdbId(newQuery) {
            searchQuery = "imdb:\(imdb)"
            return
        }

        if searchQuery.isEmpty {
            if oldQuery.count > 3 { return }
            instance.lookup.reset()
        } else if oldQuery == newQuery {
            performSearch() // always perform initial search
        } else {
            searchTextPublisher.send(searchQuery)
        }
    }
}

struct SeriesSearchItem: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        NavigationLink(value: destination) {
            SeriesGridPoster(series: series, model: model)
        }
        .buttonStyle(.plain)
    }

    var destination: SeriesPath {
        if series.exists {
            return .series(series.id)
        }

        do {
            let data = try JSONEncoder().encode(series)
            return .preview(data)
        } catch {
            leaveBreadcrumb(.fatal, category: "series.search", message: "Failed to encode", data: ["error": error])
        }

        return .search()
    }

    var model: Series? {
        guard let id = series.guid else { return nil }
        return instance.series.byId(id)
    }
}

#Preview {
    dependencies.router.selectedTab = .series
    dependencies.router.seriesPath.append(SeriesPath.search())

    return ContentView()
        .withAppState()
}
