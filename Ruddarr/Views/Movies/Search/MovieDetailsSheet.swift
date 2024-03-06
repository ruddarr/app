import os
import SwiftUI

struct MovieDetailsSheet: View {
    @State var movie: Movie

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MovieDetails(movie: movie)
                    .viewPadding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: {
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

    return MovieDetailsSheet(movie: movie)
        .withAppState()
}
