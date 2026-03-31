import SwiftUI

struct UnsupportedURLView: View {
    var close: () -> Void

    private let supportedDomains = [
        "letterboxd.com",
        "rottentomatoes.com",
        "imdb.com",
        "themoviedb.org",
        "trakt.tv",
        "thetvdb.com",
    ]

    var body: some View {
        ContentUnavailableView {
            Label("Unsupported URL", systemImage: "link.badge.plus")
        } description: {
            Text("Share a link from a supported site:\n\(supportedDomains.map { "  \u{2022} \($0)" }.joined(separator: "\n"))")
        } actions: {
            Button("Close") {
                close()
            }
        }
    }
}
