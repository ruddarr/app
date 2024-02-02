import SwiftUI

struct MovieSourcesView: View {
    @Binding var movie: Movie

    // TODO: sort by ...

    var body: some View {
        List {
            Text(movie.title)
            Text("Search Results")
        }
    }

    // 
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies[1]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.sources(movie.id))

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
