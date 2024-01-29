import SwiftUI

struct MovieView: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @State private var showMessage: Bool = false
    @State private var showingConfirmation = false

    var body: some View {
        ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .padding(.horizontal)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .refreshable {
            // TODO: refresh movie (maybe scan too?)
        }
        .overlay {
            StatusMessage(text: "Monitored", isPresenting: $showMessage)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                Button {
                    Task {
                        movie.monitored.toggle()
                        _ = await instance.movies.update(movie)

                        withAnimation { showMessage = true }
                    }
                } label: {
                    Image(systemName: "bookmark")
                        .symbolVariant(.circle.fill)
                        .foregroundStyle(.tint, .secondarySystemBackground)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    monitorButton

                    NavigationLink(
                        value: MoviesView.Path.edit(movie.id)
                    ) {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                Section {
                    Button("Automatic Search", systemImage: "magnifyingglass") {

                    }

                    Button("Interactive Search", systemImage: "person.fill") {

                    }
                }

                Section {
                    deleteMovieButton
                }
            } label: {
                Image(systemName: "ellipsis")
                    .symbolVariant(.circle/*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                    .foregroundStyle(.tint, .secondarySystemBackground)
                    .font(.title3)

            }
            .confirmationDialog(
                "Are you sure you want to delete the movie and permanently erase the movie folder and its contents?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Movie", role: .destructive) {
                    Task {
                         await deleteMovie(movie)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can’t undo this action.")
            }
        }
    }

    var monitorButton: some View {
        Button {
            Task {
                movie.monitored.toggle()
                _ = await instance.movies.update(movie)

                withAnimation { showMessage = true }
            }
        } label: {
            if movie.monitored {
                Label("Unmonitor", systemImage: "bookmark")
            } else {
                Label("Monitor", systemImage: "bookmark.fill")
            }

        }
    }

    var deleteMovieButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            showingConfirmation = true
        }
    }

    func deleteMovie(_ movie: Movie) async {
        _ = await instance.movies.delete(movie)

        dependencies.router.moviesPath.removeLast()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesView.Path.movie(movies[232].id)
    )

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
