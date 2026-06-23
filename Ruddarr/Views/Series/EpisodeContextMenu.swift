import SwiftUI
import TelemetryDeck

struct EpisodeContextMenu: View {
    var episode: Episode
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        Group {
            if encodedTitle != nil {
                link(name: "IMDb", url: imdbUrl)
            }

            if let callsheetUrl = callsheet {
                link(name: "Callsheet", url: callsheetUrl)
            }

            Divider()

            Button("Automatic Search", systemImage: "magnifyingglass") {
                Task { await dispatchSearch() }
            }
        }.tint(.primary)
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }

    func dispatchSearch() async {
        guard await instance.series.command(.episodeSearch([episode.id])) else {
            return
        }

        dependencies.toast.show(.episodeSearchQueued)

        Telemetry.record(.episodeSearchDispatched)
    }

    var encodedTitle: String? {
        episode.title?.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )
    }

    var callsheet: String? {
        #if os(iOS)
        let series: Series? = instance.series.byId(episode.seriesId)

        if let tmdbId = series?.tmdbId {
            // Callsheet deep-links down to the season level, not individual episodes.
            let url = "callsheet://open/tv/\(tmdbId)/season/\(episode.seasonNumber)"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        }
        #endif

        return nil
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
