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
                    MovieLookupSheet(instance: instance, movie: movie)
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

struct MovieLookupSheet: View {
    var instance: Instance
    var movie: Movie

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if movie.exists {
                    ScrollView {
                        MovieDetails(instance: instance, movie: movie)
                    }
                    .padding(.horizontal)
                } else {
                    MovieForm(instance: instance, movie: movie)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Add") {
                                    //
                                }
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: {
                        dismiss()
                    })
                }
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
