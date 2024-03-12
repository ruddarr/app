import SwiftUI

struct MovieView: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .refreshable {
            await refresh()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
             toolbarMonitorButton
             toolbarMenu
        }
        .alert(
            "Something Went Wrong",
            isPresented: instance.movies.errorBinding,
            presenting: instance.movies.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            if error.localizedDescription == "cancelled" {
                let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MovieView") // swiftlint:disable:this redundant_discardable_let
            }

            Text(error.localizedDescription)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await toggleMonitor() }
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
            .allowsHitTesting(!instance.movies.isWorking)
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                    editAction
                }

                Section {
                    automaticSearch
                    interactiveSearch
                }

                openInLinks
                deleteMovieButton
            } label: {
                actionMenuIcon
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

    var actionMenuIcon: some View {
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

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        NavigationLink(
            value: MoviesView.Path.edit(movie.id)
        ) {
            Label("Edit", systemImage: "pencil")
        }
    }

    var automaticSearch: some View {
        Button("Automatic Search", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
    }

    var interactiveSearch: some View {
        NavigationLink(value: MoviesView.Path.releases(movie.id), label: {
            Label("Interactive Search", systemImage: "person")
        })
    }

    var openInLinks: some View {
        Section {
            if let trailerUrl = MovieContextMenu.youTubeTrailer(movie.youTubeTrailerId) {
                Link(destination: URL(string: trailerUrl)!, label: {
                    Label("Watch Trailer", systemImage: "play")
                })
            }

            MovieContextMenu(movie: movie)
        }
    }

    var deleteMovieButton: some View {
        Section {
            Button("Delete", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }
}

extension MovieView {
    @MainActor
    func toggleMonitor() async {
        movie.monitored.toggle()

        guard await instance.movies.update(movie) else {
            return
        }

        dependencies.toast.show(movie.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func refresh() async {
        guard await instance.movies.command(movie, command: .refresh) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.movies.fetch() }
        }
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.movies.command(movie, command: .automaticSearch) else {
            return
        }

        dependencies.toast.show(.searchQueued)
    }

    @MainActor
    func deleteMovie(_ movie: Movie) async {
        _ = await instance.movies.delete(movie)

        dependencies.router.moviesPath.removeLast()
        dependencies.toast.show(.movieDeleted)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 44 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesView.Path.movie(movie.id)
    )

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
