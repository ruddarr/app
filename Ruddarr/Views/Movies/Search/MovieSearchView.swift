import SwiftUI
import Combine

struct MovieSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = false

    @Environment(RadarrInstance.self) private var instance
    @Environment(\.deviceType) private var deviceType

    let searchTextPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var movieLookup = instance.lookup

        let popularItems = discovery.movies
        let upcomingItems = discovery.upcomingMovies

        ScrollView {
            if movieLookup.sortedItems.isEmpty && searchQuery.isEmpty {
                discoveryContent(popularItems, upcomingItems)
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

    @ViewBuilder
    func discoveryContent(_ popularItems: [DiscoveryItem], _ upcomingItems: [DiscoveryItem]) -> some View {
        if deviceType == .phone {
            phoneDiscoveryContent(popularItems, upcomingItems)
        } else {
            stackedDiscoveryContent(popularItems, upcomingItems)
        }
    }

    func isDiscoveryEmpty(_ popularItems: [DiscoveryItem], _ upcomingItems: [DiscoveryItem]) -> Bool {
        popularItems.isEmpty && upcomingItems.isEmpty
    }

    func phoneDiscoveryContent(_ popularItems: [DiscoveryItem], _ upcomingItems: [DiscoveryItem]) -> some View {
        VStack(spacing: 20) {
            if !popularItems.isEmpty {
                DiscoveryRail(
                    title: "Popular This Week",
                    items: Array(popularItems.prefix(Discovery.railItemLimit)),
                    seeAllLabel: "See all popular movies",
                    destination: popularItems.count > Discovery.railItemLimit
                        ? MoviesPath.discover(.popular)
                        : nil
                )
            }

            if !upcomingItems.isEmpty {
                DiscoveryRail(
                    title: "Upcoming",
                    items: Array(upcomingItems.prefix(Discovery.railItemLimit)),
                    seeAllLabel: "See all upcoming movies",
                    destination: upcomingItems.count > Discovery.railItemLimit
                        ? MoviesPath.discover(.upcoming)
                        : nil
                )
            }
        }
        .padding(.top, 12)
        .viewBottomPadding()
        .scenePadding(.horizontal)
        .opacity(isDiscoveryEmpty(popularItems, upcomingItems) ? 0 : 1)
        .animation(.easeIn, value: popularItems)
        .animation(.easeIn, value: upcomingItems)
    }

    func stackedDiscoveryContent(_ popularItems: [DiscoveryItem], _ upcomingItems: [DiscoveryItem]) -> some View {
        VStack(spacing: 20) {
            if !popularItems.isEmpty {
                MediaGrid(items: popularItems) { item in
                    DiscoveryGridPoster(item: item)
                } header: {
                    Text("Popular This Week")
                        .padding(.top, 12)
                }
            }

            if !upcomingItems.isEmpty {
                MediaGrid(items: upcomingItems) { item in
                    DiscoveryGridPoster(item: item)
                } header: {
                    Text("Upcoming")
                        .padding(.top, 12)
                }
            }
        }
        .viewBottomPadding()
        .scenePadding(.horizontal)
        .opacity(isDiscoveryEmpty(popularItems, upcomingItems) ? 0 : 1)
        .animation(.easeIn, value: popularItems)
        .animation(.easeIn, value: upcomingItems)
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

struct MovieDiscoveryView: View {
    var section: DiscoverySection

    var body: some View {
        @Bindable var discovery = Discovery.shared

        ScrollView {
            MediaGrid(items: items(discovery)) { item in
                DiscoveryGridPoster(item: item)
            } header: {
                Text(header)
                    .padding(.top, 12)
            }
            .viewBottomPadding()
            .scenePadding(.horizontal)
        }
        .navigationTitle(navigationTitle)
        .safeNavigationBarTitleDisplayMode(.inline)
        .task {
            await discovery.fetch(.movies)
        }
    }

    func items(_ discovery: Discovery) -> [DiscoveryItem] {
        switch section {
        case .popular: discovery.movies
        case .upcoming: discovery.upcomingMovies
        }
    }

    var header: LocalizedStringKey {
        switch section {
        case .popular: "Popular This Week"
        case .upcoming: "Upcoming"
        }
    }

    var navigationTitle: LocalizedStringKey {
        switch section {
        case .popular: "Popular Movies"
        case .upcoming: "Upcoming Movies"
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesPath.search())

    return ContentView()
        .withAppState()
}
