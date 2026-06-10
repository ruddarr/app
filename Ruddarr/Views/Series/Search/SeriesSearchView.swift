import SwiftUI

struct SeriesSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = true
    @State private var searchRequest: SearchRequest?

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var seriesLookup = instance.lookup

        ScrollView {
            if seriesLookup.sortedItems.isEmpty, searchQuery.isEmpty, !instance.series.items.isEmpty {
                MediaGrid(items: discovery.series) { item in
                    DiscoveryGridPoster(item: item)
                } header: {
                    Text("Popular This Week")
                        .padding(.top, 12)
                }
                .viewBottomPadding()
                .scenePadding(.horizontal)
                .opacity(discovery.series.isEmpty ? 0 : 1)
                .animation(.easeIn, value: discovery.series)
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
        .navigationTitle("Search")
        .safeNavigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always),
            prompt: "e.g. Breaking Bad, tvdb:81189, imdb:tt0903747"
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
        }
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchQuery, initial: true, handleSearchQueryChange)
        .task(id: searchRequest) {
            guard let searchRequest, await searchRequest.waitForDebounce() else { return }

            await instance.lookup.search(query: searchRequest.query)
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

    func performSearch(debounced: Bool = false) {
        searchRequest = SearchRequest(query: searchQuery, isDebounced: debounced)
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
            performSearch(debounced: true)
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
