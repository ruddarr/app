import SwiftUI
import Combine

struct MovieSearchView: View {
    @State var searchQuery = ""

    @State private var selectedMovie: Movie?
    @State private var presentingSheet = false
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
                        selectedMovie = movie
                        presentingSheet = true
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
        .disabled(instance.isVoid || presentingSheet)
        .searchScopes($movieLookup.sort) {
            ForEach(MovieLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .onSubmit(of: .search) {
            searchTextPublisher.send(searchQuery)
        }
        .onChange(of: searchQuery) {
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
            "Something Went Wrong",
            isPresented: Binding(get: { instance.lookup.error != nil }, set: { _ in }),
            presenting: instance.lookup.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            if error.localizedDescription == "cancelled" {
                let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MovieSearchView") // swiftlint:disable:this redundant_discardable_let
            }

            Text(error.localizedDescription)
        }
        .sheet(isPresented: $presentingSheet) {
            if let movie = selectedMovie {
                if movie.exists {
                    MovieDetailsSheet(movie: movie).presentationDetents([.fraction(0.90)])
                } else {
                    MoviePreviewSheet(movie: movie).presentationDetents([.medium])
                }
            }
        }
        .overlay {
            let noSearchResults = instance.lookup.items?.count == 0 && !searchQuery.isEmpty

            if instance.lookup.isSearching && noSearchResults {
                ProgressView {
                    Text("Loading")
                }.tint(.secondary)
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
