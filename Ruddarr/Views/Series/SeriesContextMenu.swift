import SwiftUI
import TelemetryDeck

struct SeriesContextMenu: View {
    var series: Series
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        link(name: "Trakt", url: traktUrl)
        link(name: "IMDb", url: imdbUrl)
        link(name: "TVDB", url: tvdbUrl)
        
        Divider()
        
        if series.monitored {
            Button("Search Monitored", systemImage: "magnifyingglass") {
                Task { await dispatchSearch() }
            }
        }
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }
    
    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .seriesSearch(series.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "series"])
        maybeAskForReview()
    }

    var encodedTitle: String {
        series.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    var traktUrl: String {
        "https://trakt.tv/search/tvdb/\(series.tvdbId)?id_type=show"
    }

    var tvdbUrl: String {
        "http://www.thetvdb.com/?tab=series&id=\(series.tvdbId)"
    }

    var imdbUrl: String {
        #if os(iOS)
            if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
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
}
