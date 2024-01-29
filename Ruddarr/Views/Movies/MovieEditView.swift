import SwiftUI

struct MovieEditView: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MovieForm(movie: $movie)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if instance.movies.isWorking {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            await updateMovie()
                        }
                    }
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
    }

    @MainActor
    func updateMovie() async {
        await instance.movies.update(movie)

        dismiss()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies[232]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.edit(movie.id))

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
