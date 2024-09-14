import SwiftUI
import TelemetryDeck

struct MovieContextMenu: View {
    var movie: Movie
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        link(name: "Trakt", url: traktUrl)
        link(name: "Letterboxd", url: letterboxdUrl)
        link(name: "IMDb", url: imdbUrl)

        if let callsheetUrl = callsheet {
            link(name: "Callsheet", url: callsheetUrl)
        }
        
        Divider()
        
        Button("Automatic Search", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }
    
    @MainActor
    func dispatchSearch() async {
        guard await instance.movies.command(.search([movie.id])) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "movie"])
    }

    var encodedTitle: String {
        movie.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    var traktUrl: String {
        "https://trakt.tv/search/tmdb/\(movie.tmdbId)?id_type=movie"
    }

    var imdbUrl: String {
        #if os(iOS)
            if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
                if let imdbId = movie.imdbId {
                    return "imdb:///title/\(imdbId)"
                }

                return "imdb:///find/?s=tt&q=\(encodedTitle)"
            }
        #endif

        if let imdbId = movie.imdbId {
            return "https://www.imdb.com/title/\(imdbId)"
        }

        return "https://www.imdb.com/find/?s=tt&q=\(encodedTitle)"
    }

    var letterboxdUrl: String {
        #if os(iOS)
            let url = "letterboxd://x-callback-url/search?type=film&query=\(encodedTitle)"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        #endif

        return "https://letterboxd.com/search/films/\(encodedTitle)/"
    }

    var callsheet: String? {
        #if os(iOS)
            let url = "callsheet://open/movie/\(movie.tmdbId)"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        #endif

        return nil
    }

    static func youTubeTrailer(_ trailerId: String?) -> String? {
        guard let trailer = trailerId, !trailer.isEmpty else {
            return nil
        }

        #if os(iOS)
            let url = "youtube://\(trailer)"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        #endif

        return "https://www.youtube.com/watch?v=\(trailer)"
    }
}
