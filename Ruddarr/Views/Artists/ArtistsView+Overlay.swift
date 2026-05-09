import SwiftUI

struct NoArtistsSearchResults: View {
    @Binding var query: String
    @Binding var sort: ArtistSort

    var body: some View {
        let description = String(
            format: String(localized: "Check the spelling or try [adding the artist](%@)."),
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
            dependencies.router.artistsPath.append(ArtistsPath.search(query))
            query = ""

            return .handled
        })
    }
}

struct ArtistsSearchSuggestion: View {
    @Binding var query: String
    @Binding var sort: ArtistSort

    var body: some View {
        let description = String(
            format: String(localized: "Looking to [add a new artist](%@)?"),
            "#view"
        )

        Text(description.toMarkdown())
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .environment(\.openURL, .init { _ in
                dependencies.router.artistsPath.append(ArtistsPath.search(query))
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

struct NoMatchingArtists: View {
    @Binding var sort: ArtistSort

    var body: some View {
        ContentUnavailableView {
            Label("No Artists Match", systemImage: "slash.circle")
        } description: {
            Text("No artists match the selected filters.")
        } actions: {
            if sort.filter != .all {
                Button("Clear Filters") {
                    sort.filter = .all
                }
            }
        }
    }
}
