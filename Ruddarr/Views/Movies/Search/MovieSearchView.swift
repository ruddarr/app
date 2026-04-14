import SwiftUI
import Combine

struct MovieSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = false
    @State private var browseMode: Discovery.BrowseMode = .discover

    @Environment(RadarrInstance.self) private var instance
    @Environment(\.isSearching) private var isSearching

    let searchTextPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var movieLookup = instance.lookup

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
                if movieLookup.sortedItems.isEmpty && searchQuery.isEmpty {
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
            .id(browseMode)
            .scrollDismissesKeyboard(.immediately)
        }
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always)
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($movieLookup.sort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .task {
            await discovery.fetch(.movies)
            await discovery.fetch(.movies, mode: .upcoming)
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
        case .discover: Discovery.shared.movies
        case .upcoming: Discovery.shared.upcomingMovies
        }
    }

    var browseHeader: String {
        switch browseMode {
        case .discover: "Popular This Week"
        case .upcoming: "Coming Soon"
        }
    }

    func performSearch() {
        Task {
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

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesPath.search())

    return ContentView()
        .withAppState()
}
