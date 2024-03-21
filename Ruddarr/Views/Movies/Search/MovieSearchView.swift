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
                    Button {
                        dependencies.router.moviesPath.append(
                            movie.exists
                                ? MoviesView.Path.movie(movie.id)
                                : MoviesView.Path.preview(try? JSONEncoder().encode(movie))
                        )
                    } label: {
                        MovieGridItem(movie: movie)
                    }
                }
            }
            .padding(.top, 12)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Movie Search")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .disabled(instance.isVoid)
        .searchScopes($movieLookup.sort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .onSubmit(of: .search) {
            searchTextPublisher.send(searchQuery)
        }
        .onChange(of: searchQuery, initial: true) {
            searchQuery.isEmpty
                ? instance.lookup.reset()
                : searchTextPublisher.send(searchQuery)
        }
        .onReceive(searchTextPublisher.throttle(
            for: .milliseconds(750), scheduler: DispatchQueue.main, latest: true
        )) { _ in
            performSearch()
        }
        .alert(
            isPresented: instance.lookup.errorBinding,
            error: instance.lookup.error
        ) { _ in } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .overlay {
            let noSearchResults = instance.lookup.items?.count == 0 && !searchQuery.isEmpty

            if instance.lookup.isSearching && noSearchResults {
                Loading()
            } else if noSearchResults {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    func performSearch() {
        Task {
            await instance.lookup.search(query: searchQuery)
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.search())

    return ContentView()
        .withAppState()
}
