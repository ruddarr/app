import SwiftUI

struct NoMovieSearchResults: View {
    @Binding var query: String
    @Binding var sort: MovieSort

    var body: some View {
        let description = String(
            format: String(localized: "Check the spelling or try [adding the movie](%@)."),
            "#view"
        )

        ContentUnavailableView {
            Label("No Results for \"\(query)\"", systemImage: "magnifyingglass")
        } description: {
            Text(description.toMarkdown())
        } actions: {
            if sort.filter != .all {
                Button("Clear Filters") {
                    sort.filter = .all
                }
            }
        }
        .environment(\.openURL, .init { _ in
            dependencies.router.moviesPath.append(MoviesPath.search(query))
            query = ""

            return .handled
        })
    }
}

struct NoMatchingMovies: View {
    @Binding var sort: MovieSort

    var body: some View {
        ContentUnavailableView {
            Label("No Movies Match", systemImage: "slash.circle")
        } description: {
            Text("No movies match the selected filters.")
        } actions: {
            if sort.filter != .all {
                Button("Clear Filters") {
                    sort.filter = .all
                }
            }
        }
    }
}
