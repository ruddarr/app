import SwiftUI

struct MovieView: View {
    var movie: Movie

    var body: some View {
        Text(movie.title)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesView.Path.movie(movies[2].id)
    )

    return ContentView()
        .withSettings()
}
