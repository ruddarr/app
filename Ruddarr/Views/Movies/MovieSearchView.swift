import SwiftUI

struct MovieSearchView: View {
    let instance: Instance

    @State var searchQuery = ""

    @State private var isAddingMovie: Movie?
    @State private var presentingSearch = true
    @State private var lookup = MovieLookupModel()

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(lookup.movies ?? []) { movie in
                    MovieRow(movie: movie)
                        .opacity(movie.exists ? 0.35 : 1)
                        .onTapGesture {
                            isAddingMovie = movie
                        }
                }
                .sheet(item: $isAddingMovie) { movie in
                    MovieSearchSheet(instance: instance, movie: movie)
                        .presentationDetents(
                            movie.exists ? [.large] : [.medium]
                        )
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
        }
        .navigationTitle("Add Movie")
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            lookup.movies = nil
        }
        .onSubmit(of: .search) {
            Task {
                await lookup.search(instance, query: searchQuery)
            }
        }
        .alert("Something Went Wrong", isPresented: $lookup.hasError, presenting: lookup.error) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if lookup.isSearching {
                ProgressView {
                    Text("Loading")
                }
            } else if lookup.movies?.count == 0 {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.search())

    return ContentView()
        .withSettings()
}
