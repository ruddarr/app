import SwiftUI
import TelemetryClient

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
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
             toolbarMonitorButton
             toolbarMenu
        }
        .alert(
            isPresented: instance.movies.errorBinding,
            error: instance.movies.error
        ) { _ in
            Button("OK") { instance.movies.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete Movie", role: .destructive) {
                Task { await deleteMovie() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the movie and permanently erase its folder and its contents.")
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: $movie.monitored)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.movies.isWorking)
            .id(UUID())
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                    automaticSearch
                    interactiveSearch
                }

                openInLinks

                Section {
                    editAction
                    deleteMovieButton
                }
            } label: {
                ToolbarActionButton()
            }
            .id(UUID())
        }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        NavigationLink(
            value: MoviesPath.edit(movie.id)
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
        NavigationLink(
            value: MoviesPath.releases(movie.id)
        ) {
            Label("Interactive Search", systemImage: "person")
        }
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
        Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
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
        guard await instance.movies.command(.refresh([movie.id])) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.movies.fetch() }
        }
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.movies.command(.search([movie.id])) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        TelemetryManager.send("automaticSearchDispatched", with: ["type": "movie"])
    }

    @MainActor
    func deleteMovie() async {
        _ = await instance.movies.delete(movie)

        if !dependencies.router.moviesPath.isEmpty {
            dependencies.router.moviesPath.removeLast()
        }

        dependencies.toast.show(.movieDeleted)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesPath.movie(movie.id)
    )

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
