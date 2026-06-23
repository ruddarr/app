import SwiftUI
import TelemetryDeck

struct SeriesLinks: View {
    var series: Series

    var body: some View {
        link(name: "Trakt", url: traktUrl)
        link(name: "IMDb", url: imdbUrl)
        link(name: "TVDB", url: tvdbUrl)

        if let callsheetUrl = callsheet {
            link(name: "Callsheet", url: callsheetUrl)
        }
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }

    var encodedTitle: String {
        series.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? series.title
    }

    var traktUrl: String {
        if let imdbId = series.imdbId {
            return "https://app.trakt.tv/shows/\(imdbId)"
        }

        return "https://app.trakt.tv/search?m=show&q=\(encodedTitle)"
    }

    var tvdbUrl: String {
        "https://www.thetvdb.com/?tab=series&id=\(series.tvdbId)"
    }

    var imdbUrl: String {
        #if os(iOS)
            if let url = URL(string: "imdb://"), UIApplication.shared.canOpenURL(url) {
                if let imdbId = series.imdbId {
                    return "imdb:///title/\(imdbId)"
                }

                return "imdb:///find/?s=tt&q=\(encodedTitle)"
            }
        #endif

        if let imdbId = series.imdbId {
            return "https://www.imdb.com/title/\(imdbId)"
        }

        return "https://www.imdb.com/find/?s=tt&q=\(encodedTitle)"
    }

    var callsheet: String? {
        #if os(iOS)
            if let tmdbId = series.tmdbId {
                let url = "callsheet://open/tv/\(tmdbId)"

                if let link = URL(string: url), UIApplication.shared.canOpenURL(link) {
                    return url
                }
            }
        #endif

        return nil
    }
}
