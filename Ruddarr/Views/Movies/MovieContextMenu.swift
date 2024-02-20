import SwiftUI

struct MovieContextMenu: View {
    var movie: Movie

    var body: some View {
        link(name: "Trakt", url: traktUrl)
        link(name: "IMDb", url: imdbUrl)
        link(name: "Letterboxd", url: letterboxdUrl)

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
        movie.title.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
    }

    var traktUrl: String {
        "https://trakt.tv/search/tmdb/\(movie.tmdbId)?id_type=movie"
    }

    var imdbUrl: String {
        if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
            if let imdbId = movie.imdbId {
                return "imdb:///title/\(imdbId)"
            }

            return "imdb:///find?q=\(encodedTitle)"
        }

        if let imdbId = movie.imdbId {
            return "https://www.imdb.com/title/\(imdbId)"
        }

        return "https://www.imdb.com/find/?q=\(encodedTitle)"
    }

    var letterboxdUrl: String {
        let url = "letterboxd://x-callback-url/search?type=film&query=\(encodedTitle)"

        if UIApplication.shared.canOpenURL(URL(string: url)!) {
            return url
        }

        return "https://letterboxd.com/search/films/\(encodedTitle)/"
    }

    var callsheet: String? {
        let url = "callsheet://open/movie/\(movie.tmdbId)"

        if UIApplication.shared.canOpenURL(URL(string: url)!) {
            return url
        }

        return nil
    }
}
