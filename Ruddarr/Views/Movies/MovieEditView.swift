import SwiftUI

struct MovieEditView: View {
    var instance: Instance

    @State var movie: Movie

    var body: some View {
        MovieForm(instance: instance, movie: $movie)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        //
                    }
                }
            }
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
}
