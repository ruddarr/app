import SwiftUI

struct EpisodeContextMenu: View {
    var episode: Episode

    var body: some View {
        link(name: "Trakt", url: traktUrl)

        if encodedTitle != nil {
            link(name: "IMDb", url: imdbUrl)
        }
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }

    var encodedTitle: String? {
        episode.title?.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )
    }

    var traktUrl: String {
        "https://trakt.tv/search/tvdb/\(episode.tvdbId)?id_type=episode"
    }

    var imdbUrl: String {
        #if os(iOS)
            if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
                return "imdb:///find/?s=ep&q=\(encodedTitle ?? "")"
            }
        #endif

        return "https://www.imdb.com/find/?s=ep&q=\(encodedTitle ?? "")"
    }
}
