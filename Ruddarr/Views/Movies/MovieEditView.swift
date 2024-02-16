import SwiftUI

struct MovieEditView: View {
    @Binding var movie: Movie

    init(movie: Binding<Movie>) {
        self._movie = movie
        _currentRootFolder = State(initialValue: movie.wrappedValue.rootFolderPath?.untrailingSlashIt)
    }

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    @State private var currentRootFolder: String?
    @State private var showConfirmation: Bool = false

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
                Text(error.localizedDescription)
            }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Save") {
                    if movie.exists && currentRootFolder != movie.rootFolderPath?.untrailingSlashIt {
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

    @MainActor
    func updateMovie(moveFiles: Bool = false) async {
        _ = await instance.movies.update(movie, moveFiles: moveFiles)

        dismiss()
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
