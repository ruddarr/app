import SwiftUI

struct NoMovieSearchResults: View {
    @Binding var query: String
    @Binding var sort: MovieSort

    var body: some View {
        let description = String(localized: "Check the spelling or try [adding the movie](%@).")
            .placeholders("#view")

        ContentUnavailableView {
            Label("No Results for \"\(query)\"", systemImage: "magnifyingglass")
        } description: {
            Text(description.toMarkdown())
        } actions: {
            if sort.isFiltered {
                Button("Clear Filters") {
                    sort.clearFilters()
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

struct MovieSearchSuggestion: View {
    @Binding var query: String
    @Binding var sort: MovieSort

    var body: some View {
        let description = String(localized: "Looking to [add a new movie](%@)?")
            .placeholders("#view")

        Text(description.toMarkdown())
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .environment(\.openURL, .init { _ in
                dependencies.router.moviesPath.append(MoviesPath.search(query))
                query = ""

                return .handled
            })

        if sort.isFiltered {
            Button("Clear Filters") {
                sort.clearFilters()
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
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
            if sort.isFiltered {
                Button("Clear Filters") {
                    sort.clearFilters()
                }
            }
        }
    }
}
