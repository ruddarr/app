import SwiftUI

struct MovieSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = true
    @State private var searchRequest: SearchRequest?

    @AppStorage("discoveryHideItems", store: dependencies.store) private var hideLibraryItems: Bool = false

    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var movieLookup = instance.lookup

        ScrollView {
            if shouldShowDiscoveryGrid {
                MediaGrid(items: discoveryItems) { item in
                    DiscoveryGridPoster(item: item)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } header: {
                    DiscoveryGridHeader(hideLibraryItems: $hideLibraryItems)
                        .padding(.top, deviceType == .pad ? 32 : 12)
                }
                .viewBottomPadding()
                .scenePadding(.horizontal)
                .opacity(discovery.movies.isEmpty ? 0 : 1)
                .animation(.easeIn, value: discovery.movies)
                .animation(.snappy, value: hideLibraryItems)
            } else {
                MediaGrid(items: movieLookup.sortedItems) { movie in
                    NavigationLink(value: movie.exists
                       ? MoviesPath.movie(movie.id)
                       : MoviesPath.preview(try? JSONEncoder().encode(movie))
                    ) {
                        MovieGridPoster(movie: movie)
                    }.buttonStyle(.plain)
                }
                .padding(.top, 12)
                .scenePadding(.horizontal)
                .viewBottomPadding()
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always),
            prompt: Text(
                "e.g. \("Interstellar, tmdb:157336, imdb:tt0816692")",
                comment: "Placeholder in the search field on the Add Movie/Series screens (translate only \"e.g.\", short form of \"for example\")"
            )
        )
        .dismissSearchWhenHidden($searchPresented)
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($movieLookup.sort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .task {
            await discovery.fetch(.movies)
        }
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchQuery, initial: true, handleSearchQueryChange)
        .task(id: searchRequest) {
            guard let searchRequest, await searchRequest.waitForDebounce() else { return }

            await instance.lookup.search(query: searchRequest.query)
        }
        .sensoryAlert(
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

    var shouldShowDiscoveryGrid: Bool {
        instance.lookup.isEmpty() && searchQuery.isEmpty
    }

    var discoveryItems: [DiscoveryItem] {
        let items = Discovery.shared.movies
        guard hideLibraryItems else { return items }

        return items.filter { $0.libraryMovie(in: instance) == nil }
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

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesPath.search())

    return ContentView()
        .withAppState()
}
