import SwiftUI

struct MoviePreviewView: View {
    @State var movie: Movie

    @State private var presentingForm: Bool = false

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                MovieForm(movie: $movie)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
            }
            .presentationDetents([.medium])
        }
        .alert(
            isPresented: instance.movies.errorBinding,
            error: instance.movies.error
        ) { _ in
            Button("OK") { instance.movies.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
                presentingForm = false
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add to Library") {
                presentingForm = true
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Done") {
                    Task {
                        await addMovie()
                    }
                }
            }
        }
    }

    @MainActor
    func addMovie() async {
        guard await instance.movies.add(movie) else {
            leaveBreadcrumb(.error, category: "view.movie.preview", message: "Failed to add movie", data: ["error": instance.movies.error ?? ""])

            return
        }

        guard let addedMovie = instance.movies.byTmdbId(movie.tmdbId) else {
            fatalError("Failed to locate added movie by tmdbId")
        }

        instance.lookup.reset()
        presentingForm = false

        let moviePath = MoviesView.Path.movie(addedMovie.id)

        dependencies.router.moviesPath.removeLast(dependencies.router.moviesPath.count)
        dependencies.router.moviesPath.append(moviePath)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.tmdbId == 736_308 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesView.Path.preview(
            try? JSONEncoder().encode(movie)
        )
    )

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
