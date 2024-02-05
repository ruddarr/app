import os
import SwiftUI

struct MovieSearchSheet: View {
    @State var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    private let log: Logger = logger("view")

    var body: some View {
        NavigationStack {
            Group {
                if movie.exists {
                    ScrollView {
                        MovieDetails(movie: movie)
                        .padding(.horizontal)
                    }
                } else {
                    MovieForm(movie: $movie)
                    .toolbar {
                        toolbarSaveButton
                    }
                }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: {
                        dismiss()
                    })
                }
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Add") {
                    Task {
                        await addMovie()
                    }
                }
            }
        }
    }

    func addMovie() async {
        guard await instance.movies.add(movie) else {
            log.error("Failed to add movie: \(instance.movies.error)")

            return
        }

        guard let addedMovie = instance.movies.byTmdbId(movie.tmdbId) else {
            fatalError("Failed to locate added movie by tmdbId")
        }

        dismiss()

        dependencies.router.moviesPath.removeLast(
            dependencies.router.moviesPath.count
        )

        dependencies.router.moviesPath.append(
            MoviesView.Path.movie(addedMovie.id)
        )
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 5 }) ?? movies[0]

    return MovieSearchSheet(movie: movie)
        .withAppState()
}

#Preview("Existing") {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 236 }) ?? movies[0]

    return MovieSearchSheet(movie: movie)
        .withAppState()
}
