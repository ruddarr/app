import SwiftUI

struct NoSeriesSearchResults: View {
    @Binding var query: String

    var body: some View {
        let description = String(
            format: String(localized: "Check the spelling or try [adding the series](%@)."),
            "#view"
        )

        return ContentUnavailableView(
            "No Results for \"\(query)\"",
            systemImage: "magnifyingglass",
            description: Text(description.toMarkdown())
        ).environment(\.openURL, .init { _ in
            dependencies.router.seriesPath.append(SeriesPath.search(query))
            query = ""
            return .handled
        })
    }
}

struct NoMatchingSeries: View {
    var body: some View {
        ContentUnavailableView(
            "No Series Match",
            systemImage: "slash.circle",
            description: Text("No series match the selected filters.")
        )
    }
}
