import SwiftUI

struct MovieView: View {
    var instance: Instance
    var movie: Movie

    var body: some View {
        // movie.remoteFanart ???

        ScrollView {
            MovieDetails(instance: instance, movie: movie)
                .padding(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .padding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: MoviesView.Path.edit(movie.id)) {
                    Text("Edit")
                }
            }
        }
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
