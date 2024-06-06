import SwiftUI
import Combine

struct MovieSearchView: View {
    @State var searchQuery = ""

    @State private var presentingSearch = true

    @Environment(RadarrInstance.self) private var instance

    let searchTextPublisher = PassthroughSubject<String, Never>()

    let gridItemLayout = MovieGridItem.gridItemLayout()
    let gridItemSpacing = MovieGridItem.gridItemSpacing()

    var body: some View {
        @Bindable var movieLookup = instance.lookup

        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
                ForEach(movieLookup.sortedItems) { movie in
                    NavigationLink(value: movie.exists
                       ? MoviesPath.movie(movie.id)
                       : MoviesPath.preview(try? JSONEncoder().encode(movie))
                    ) {
                        MovieGridItem(movie: movie)
                    }
                }
            }
            .padding(.top, 12)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Search")
        .safeNavigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .drawerOrToolbar
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($movieLookup.sort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.label)
            }
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
        }
        .overlay {
            if instance.lookup.isSearching && instance.lookup.isEmpty() {
                Loading()
            } else if instance.lookup.noResults(searchQuery) {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    func performSearch() {
        Task {
            await instance.lookup.search(query: searchQuery)
        }
    }

    func handleSearchQueryChange(oldQuery: String, newQuery: String) {
        if searchQuery.isEmpty {
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
