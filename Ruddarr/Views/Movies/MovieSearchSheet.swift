import SwiftUI

struct MovieSearchSheet: View {
    var instance: Instance
    @State var movie: Movie

    @State private var movies = MovieModel()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if movie.exists {
                    ScrollView {
                        MovieDetails(instance: instance, movie: movie)
                    }
                    .padding(.horizontal)
                } else {
                    MovieForm(instance: instance, movie: $movie)
                    // .background(.secondary)
                    .toolbar {
                        toolbarSaveButton
                    }
                }
            }
            .alert("Something Went Wrong", isPresented: $movies.hasError, presenting: movies.error) { _ in
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
            if movies.isWorking {
                ProgressView()
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
        guard let movie = await movies.add(movie, instance) else {
            return
        }

        dismiss()

        dependencies.router.moviesPath.removeLast(
            dependencies.router.moviesPath.count
        )

        dependencies.router.moviesPath.append(
            MoviesView.Path.movie(movie.id)
        )
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")

    return MovieSearchSheet(
        instance: .sample,
        movie: movies[5]
    )
}

#Preview("Existing") {
    let movies: [Movie] = PreviewData.load(name: "movies")

    return MovieSearchSheet(
        instance: .sample,
        movie: movies[2]
    )
}
