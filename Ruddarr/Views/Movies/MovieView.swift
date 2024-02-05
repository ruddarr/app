import SwiftUI

struct MovieView: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @State private var showMonitored: Bool = false
    @State private var showUnmonitored: Bool = false
    @State private var showSearchStarted: Bool = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        print("body")
        return ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
                .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .refreshable {
            // TODO: refresh movie
        }
        .overlay(alignment: .top) {
            StatusMessage(text: "Monitored", icon: "bookmark.fill", isPresenting: $showMonitored)
            StatusMessage(text: "Unmonitored", icon: "bookmark", isPresenting: $showUnmonitored)

            StatusMessage(text: "Search Started", icon: "checkmark", isPresenting: $showSearchStarted)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                Button {
                    Task {
                        guard await instance.movies.update(movie) else {
                            return
                        }

                        movie.monitored.toggle()

                        withAnimation {
                            movie.monitored ? (showMonitored = true) : (showUnmonitored = true)
                        }
                    }
                } label: {
                    Circle()
                        .fill(.secondarySystemBackground)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "bookmark")
                                .font(.system(size: 11, weight: .bold))
                                .symbolVariant(movie.monitored ? .fill : .none)
                                .foregroundStyle(.tint)
                        }
                }
                .buttonStyle(.plain)
//                .allowsHitTesting(!instance.movies.isWorking)
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
                        Task {
                            guard await instance.movies.command(movie, command: .automaticSearch) else {
                                return
                            }

                            withAnimation {
                                showSearchStarted = true
                            }
                        }
                    }

                    NavigationLink(value: MoviesView.Path.releases(movie.id), label: {
                        Label("Interactive Search", systemImage: "person.fill")
                    })
                }

                Section {
                    deleteMovieButton
                }
            } label: {
                Circle()
                    .fill(.secondarySystemBackground)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .symbolVariant(.fill)
                            .font(.system(size: 12, weight: .bold))
                            .symbolVariant(movie.monitored ? .fill : .none)
                            .foregroundStyle(.tint)
                    }
            }
            .confirmationDialog(
                "Are you sure you want to delete the movie and permanently erase the movie folder and its contents?",
                isPresented: $showDeleteConfirmation,
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
                guard await instance.movies.update(movie) else {
                    return
                }

                movie.monitored.toggle()

                withAnimation {
                    movie.monitored ? (showMonitored = true) : (showUnmonitored = true)
                }
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
            showDeleteConfirmation = true
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
