import SwiftUI

// TODO: needs work...
struct SeriesContextMenu: View {
    var series: Series

    var body: some View {
        link(name: "Trakt", url: traktUrl)
        link(name: "IMDb", url: imdbUrl)
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }

    var encodedTitle: String {
        series.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    var traktUrl: String {
        "https://trakt.tv/search/tvdb/\(series.tvdbId)?id_type=show"
    }

    var imdbUrl: String {
        if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
            if let imdbId = series.imdbId {
                return "imdb:///title/\(imdbId)"
            }

            return "imdb:///find?q=\(encodedTitle)"
        }

        if let imdbId = series.imdbId {
            return "https://www.imdb.com/title/\(imdbId)"
        }

        return "https://www.imdb.com/find/?q=\(encodedTitle)"
    }
}
