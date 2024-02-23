import SwiftUI
import Combine

struct MovieSearchView: View {
    @State var searchQuery = ""

    @State private var isAddingMovie: Movie?
    @State private var presentingSearch = true

    @Environment(RadarrInstance.self) private var instance

    let searchTextPublisher = PassthroughSubject<String, Never>()
    let gridItemLayout = MovieGridItem.gridItemLayout()

    @State var searchSort: MovieLookup.SortOption = .byRelevance

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(sortedItems) { movie in
                    MovieGridItem(movie: movie)
                        .onTapGesture {
                            isAddingMovie = movie
                        }
                }
                .sheet(item: $isAddingMovie) { movie in
                    MovieSearchSheet(movie: movie)
                        .presentationDetents(
                            movie.exists ? [.large] : [.medium]
                        )
                }
            }
            .padding(.top, 10)
            .scenePadding(.horizontal)
        }
        .navigationTitle("Add Movie")
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .searchScopes($searchSort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.rawValue)
            }
        }
        .onChange(of: searchQuery) {
            searchTextPublisher.send(searchQuery)
        }
        .onReceive(
            searchTextPublisher.throttle(for: .milliseconds(750), scheduler: DispatchQueue.main, latest: true)
        ) { _ in
            Task {
                await instance.lookup.search(query: searchQuery)
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.lookup.error != nil }, set: { _ in }),
            presenting: instance.lookup.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            let noSearchResults = instance.lookup.items?.isEmpty ?? true

            if instance.lookup.isSearching && noSearchResults {
                ProgressView {
                    Text("Loading")
                }.tint(.secondary)
            } else if noSearchResults {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    var sortedItems: [Movie] {
        let items = instance.lookup.items ?? []

        guard searchSort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch searchSort {
            case .byRelevance: $0.id < $1.id
            case .byYear: $0.year < $1.year
            case .byPopularity: $0.popularity ?? 0 < $1.popularity ?? 0
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.search())

    return ContentView()
        .withAppState()
}
