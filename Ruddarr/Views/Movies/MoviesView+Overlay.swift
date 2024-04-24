import SwiftUI

struct NoInstance: View {
    let type: String

    var body: some View {
        let description = String(
            format: String(localized: "Connect a %@ instance under %@."),
            type,
            String(format: "[%@](#view)", String(localized: "Settings"))
        )

        return ContentUnavailableView(
            "No \(type) Instance",
            systemImage: "externaldrive.badge.xmark",
            description: Text(description.toMarkdown())
        ).environment(\.openURL, .init { _ in
            dependencies.router.selectedTab = .settings
            return .handled
        })
    }
}

struct NoMovieSearchResults: View {
    @Binding var query: String

    var body: some View {
        let description = String(
            format: String(localized: "Check the spelling or try [adding the movie](%@)."),
            "#view"
        )

        return ContentUnavailableView(
            "No Results for \"\(query)\"",
            systemImage: "magnifyingglass",
            description: Text(description.toMarkdown())
        ).environment(\.openURL, .init { _ in
            dependencies.router.moviesPath.append(MoviesView.Path.search(query))
            query = ""
            return .handled
        })
    }
}

struct NoMatchingMovies: View {
    var body: some View {
        ContentUnavailableView(
            "No Movies Match",
            systemImage: "slash.circle",
            description: Text("No movies match the selected filters.")
        )
    }
}
