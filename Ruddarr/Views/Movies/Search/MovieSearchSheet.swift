import os
import SwiftUI

struct MovieSearchSheet: View {
    @State var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if movie.exists {
                    ScrollView {
                        MovieDetails(movie: movie)
                            .scenePadding(.horizontal)
                    }
                } else {
                    MoviePreview(movie: $movie)
                }
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
