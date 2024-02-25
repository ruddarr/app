import Foundation
import UIKit
import SwiftUI

struct QuickActions {
    var registerShortcutItems: () -> Void = {
        UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
    }

    var addMovie: () -> Void = {
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesView.Path.search()])
    }

    var searchMovieByTMDBID: (Movie.TMDBID) -> Void = { tmdbID in
        if let movie = dependencies.radarrInstance?.movies.items.first(where: { $0.tmdbId == tmdbID }) {
            dependencies.router.selectedTab = .movies
            dependencies.router.moviesPath = .init([MoviesView.Path.movie(movie.id)])
        } else {
            dependencies.toast.show(.error("Couldn't find movie with tmbdID \(tmdbID)"))
        }
    }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case addMovie
        case searchMovie(tmdbID: Movie.TMDBID)

        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .addMovie:
                dependencies.quickActions.addMovie()
            case .searchMovie(let tmbdID):
                dependencies.quickActions.searchMovieByTMDBID(tmbdID)
            }
        }
    }
}

extension QuickActions.Deeplink {
    init(url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppError("Unsupported URL: \(url.absoluteString)")
        }

        let action = (components.host ?? "") + components.path

        switch action.untrailingSlashIt {
        case "", "open":
            self = .openApp
        case "movies/add":
            self = .addMovie
        case "movies/search":
            guard let tmdbID = components[queryParameter: "tmdbID"].flatMap(Movie.TMDBID.init) else {
                throw DecodingError.valueNotFound(Movie.TMDBID.self, .init(codingPath: [], debugDescription: "tmbdID not found in searchMovie URL"))
            }

            self = .searchMovie(tmdbID: tmdbID)
        default:
            throw AppError("Unsupported URL: \(url.absoluteString)")
        }
    }
}

extension QuickActions {
    enum ShortcutItem: String, CaseIterable {
        case addMovie

        var title: String {
            switch self {
            case .addMovie: "Add New Movie"
            }
        }

        var icon: UIApplicationShortcutIcon {
            switch self {
            case .addMovie: UIApplicationShortcutIcon(type: .add)
            }
        }

        func callAsFunction() {
            switch self {
            case .addMovie: dependencies.quickActions.addMovie()
            }
        }
    }
}

extension QuickActions.ShortcutItem {
    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(type: rawValue, localizedTitle: title, localizedSubtitle: nil, icon: icon)
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
