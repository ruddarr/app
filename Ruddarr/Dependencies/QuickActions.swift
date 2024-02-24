import Foundation
import UIKit
import SwiftUI

struct QuickActions {
    var registerShortcutItems: () -> Void = {
        UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
    }

    var addMovie: () -> Void = {
        dependencies.router.goToSearch()
    }

    var searchMovieByTMDBID: (Movie.TMDBID) -> Void = { tmdbID in
        if let movie = dependencies.radarrInstance?.movies.items.first(where: { $0.tmdbId == tmdbID }) {
            dependencies.router.selectedTab = .movies
            dependencies.router.moviesPath = .init([MoviesView.Path.movie(movie.id)])
        } else {
            dependencies.toast.show(AnyView(Text("Couldn't find movie with tmbdID \(tmdbID)")))
        }
    }
}

extension QuickActions {
    enum Deeplink {
        case searchMovie(tmdbID: Movie.TMDBID)

        func callAsFunction() {
            switch self {
            case .searchMovie(let tmbdID):
                dependencies.quickActions.searchMovieByTMDBID(tmbdID)
            }
        }
    }
}

extension QuickActions.Deeplink {
    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw AppError("Unsupported URL")}
        guard components.scheme == "ruddarr" else { throw AppError("Unsupported URL scheme") }

        switch components.host {
        case "searchMovie":
            guard let tmdbID = components[queryParameter: "tmdbID"].flatMap(Movie.TMDBID.init) else {
                throw DecodingError.valueNotFound(Movie.TMDBID.self, .init(codingPath: [], debugDescription: "tmbdID not found in searchMovie URL"))
            }
            self = .searchMovie(tmdbID: tmdbID)
        default:
            throw AppError("Unknown deeplink URL.")
        }
    }
}

extension QuickActions {
    enum ShortcutItem: String, CaseIterable {
        case addMovie

        var title: String {
            switch self {
            case .addMovie:
                "Add Movie"
            }
        }

        var icon: UIApplicationShortcutIcon {
            switch self {
            case .addMovie:
                UIApplicationShortcutIcon(type: .add)
            }
        }

        func callAsFunction() {
            switch self {
            case .addMovie:
                dependencies.quickActions.addMovie()
            }
        }
    }
}

extension QuickActions.ShortcutItem {
    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(type: rawValue, localizedTitle: title, localizedSubtitle: "", icon: icon)
    }

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }
}

fileprivate extension URLComponents {
    subscript(queryParameter queryParameter: String) -> String? {
        queryItems?.first(where: { $0.name == queryParameter })?.value
    }
}
