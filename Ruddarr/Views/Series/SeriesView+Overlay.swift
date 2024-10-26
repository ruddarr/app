import SwiftUI

struct NoSeriesSearchResults: View {
    @Binding var query: String
    @Binding var sort: SeriesSort

    var body: some View {
        let description = String(
            format: String(localized: "Check the spelling or try [adding the series](%@)."),
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
            dependencies.router.seriesPath.append(SeriesPath.search(query))
            query = ""

            return .handled
        })
    }
}

struct SeriesSearchSuggestion: View {
    @Binding var query: String
    @Binding var sort: SeriesSort

    var body: some View {
        let description = String(
            format: String(localized: "Looking to [add a new series](%@)?"),
            "#view"
        )

        Text(description.toMarkdown())
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .environment(\.openURL, .init { _ in
                dependencies.router.moviesPath.append(MoviesPath.search(query))
                query = ""

                return .handled
            })

        if sort.filter != .all {
            Button("Clear Filters") {
                sort.filter = .all
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
    }
}

struct NoMatchingSeries: View {
    @Binding var sort: SeriesSort

    var body: some View {
        ContentUnavailableView {
            Label("No Series Match", systemImage: "slash.circle")
        } description: {
            Text("No series match the selected filters.")
        } actions: {
            if sort.filter != .all {
                Button("Clear Filters") {
                    sort.filter = .all
                }
            }
        }
    }
}
