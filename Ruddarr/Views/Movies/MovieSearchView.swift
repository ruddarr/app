import SwiftUI

struct MovieSearchView: View {
    @State var searchQuery = ""

    @State private var isAddingMovie: Movie?
    @State private var presentingSearch = true

    @Environment(RadarrInstance.self) private var instance

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(instance.lookup.items ?? []) { movie in
                    MovieRow(movie: movie)
                        .opacity(movie.exists ? 0.35 : 1)
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
            .padding(.horizontal)
        }
        .navigationTitle("Add Movie")
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            instance.lookup.items = nil
        }
        .onSubmit(of: .search) {
            Task {
                await instance.lookup.search(query: searchQuery)
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.lookup.hasError }, set: { _ in }),
            presenting: instance.lookup.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if instance.lookup.isSearching {
                ProgressView {
                    Text("Loading")
                }
            } else if instance.lookup.items?.count == 0 {
                ContentUnavailableView.search(text: searchQuery)
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
