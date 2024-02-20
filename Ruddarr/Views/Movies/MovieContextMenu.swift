import SwiftUI

// TODO: can we perform a check if the app is installed or the URL can be opened?
// https://medium.com/@contact.jmeyers/complete-list-of-ios-url-schemes-for-third-party-apps-always-updated-5663ef15bdff
// https://stackoverflow.com/questions/7961479/start-imdb-ios-app-through-safari-does-it-accept-commands
// https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app?source=post_page-----6251d7f7ff4b--------------------------------




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
        return "https://trakt.tv/search/tmdb/\(movie.tmdbId)?id_type=movie"
    }

    var imdbUrl: String {
        if UIApplication.shared.canOpenURL(URL(string: "imdb://")!) {
            if let imdbId = movie.imdbId {
                return "imdb:///title/\(movie.imdbId!)"
            } else {
                return "imdb:///find?q=\(encodedTitle)"
            }
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
