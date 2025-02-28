import SwiftUI

struct MovieEditView: View {
    @Binding var movie: Movie

    init(movie: Binding<Movie>) {
        self._movie = movie
        self._unmodifiedMovie = State(initialValue: movie.wrappedValue)
    }

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmation: Bool = false
    @State private var savedChanges: Bool = false
    @State private var unmodifiedMovie: Movie

    var body: some View {
        MovieForm(movie: $movie)
            .padding(.top, -20)
            .navigationTitle(movie.title)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarSaveButton
            }
            .onDisappear {
                if !savedChanges {
                    undoMovieChanges()
                }
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
                "Move the movie files to \"\(movie.rootFolderPath ?? "")\"?",
                isPresented: $showConfirmation
            ) {
                Button("Move Files", role: .destructive) {
                    Task { await updateMovie(moveFiles: true) }
                }
                Button("No") {
                    Task { await updateMovie() }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Save") {
                    if movie.exists && hasRootFolderChanged() {
                        showConfirmation = true
                    } else {
                        Task { await updateMovie() }
                    }
                }
            }
        }
    }

    func hasRootFolderChanged() -> Bool {
        movie.rootFolderPath?.untrailingSlashIt != unmodifiedMovie.rootFolderPath?.untrailingSlashIt
    }

    func updateMovie(moveFiles: Bool = false) async {
        _ = await instance.movies.update(movie, moveFiles: moveFiles)

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        savedChanges = true

        dismiss()
    }

    func undoMovieChanges() {
        movie.monitored = unmodifiedMovie.monitored
        movie.minimumAvailability = unmodifiedMovie.minimumAvailability
        movie.qualityProfileId = unmodifiedMovie.qualityProfileId
        movie.rootFolderPath = unmodifiedMovie.rootFolderPath
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesPath.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesPath.edit(movie.id))

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
