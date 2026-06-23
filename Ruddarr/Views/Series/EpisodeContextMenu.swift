import SwiftUI
import TelemetryDeck

struct EpisodeContextMenu: View {
    var episode: Episode
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        Group {
            link(name: "Trakt", url: traktUrl)

            if encodedTitle != nil {
                link(name: "IMDb", url: imdbUrl)
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

    var traktUrl: String {
        // Trakt's v3 web app dropped external-id redirects; episodes have no IMDb
        // id, so fall back to the series (IMDb id when known, otherwise its title).
        let series: Series? = instance.series.byId(episode.seriesId)
        let query = series?.imdbId ?? series?.title ?? episode.titleLabel
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        return "https://app.trakt.tv/search?q=\(encoded)"
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
