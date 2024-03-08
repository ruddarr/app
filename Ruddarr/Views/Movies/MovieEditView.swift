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
            .toolbar {
                toolbarSaveButton
            }
            .alert(
                "Something Went Wrong",
                isPresented: Binding(get: { instance.movies.error != nil }, set: { _ in }),
                presenting: instance.movies.error
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                if error.localizedDescription == "cancelled" {
                    let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MovieEditView") // swiftlint:disable:this redundant_discardable_let
                }

                Text(error.localizedDescription)
            }
            .onDisappear {
                if !savedChanges {
                    undoMovieChanges()
                }
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
                .confirmationDialog(
                    "Move Files",
                    isPresented: $showConfirmation,
                    titleVisibility: .hidden
                ) {
                    Button("Move Files", role: .destructive) {
                        Task { await updateMovie(moveFiles: true) }
                    }
                    Button("No") {
                        Task { await updateMovie() }
                    }
                    Button("Cancel", role: .cancel) {
                        showConfirmation = false
                    }
                } message: {
                    Text("Would you like to move the movie folder to \"\(movie.rootFolderPath!)\"?")
                }
            }
        }
    }

    func hasRootFolderChanged() -> Bool {
        movie.rootFolderPath?.untrailingSlashIt != unmodifiedMovie.rootFolderPath?.untrailingSlashIt
    }

    @MainActor
    func updateMovie(moveFiles: Bool = false) async {
        _ = await instance.movies.update(movie, moveFiles: moveFiles)
        savedChanges = true

        dismiss()
    }

    func undoMovieChanges() {
        movie.monitored = unmodifiedMovie.monitored
        movie.minimumAvailability = unmodifiedMovie.minimumAvailability
        movie.qualityProfileId = unmodifiedMovie.qualityProfileId
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 232 }) ?? movies[0]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.edit(movie.id))

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
