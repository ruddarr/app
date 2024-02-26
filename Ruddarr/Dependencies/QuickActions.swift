import Foundation
import UIKit
import SwiftUI

struct QuickActions {
    var registerShortcutItems: () -> Void = {
        UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
    }

    var searchMovies: (String) -> Void = { query in
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesView.Path.search(query)])
    }

    // var openMovieId: Movie.ID?
    //
    // var openMovie: (Movie.TMDBID) -> Void = { tmdbId in
    //    dependencies.quickActions.openMovieId = tmdbId
    //    dependencies.router.selectedTab = .movies
    //    dependencies.router.moviesPath = .init()
    // }
    //
    // We can use `.onChange(of: scenePhase)` in `MoviesView`
    // 
    // if let id = dependencies.quickActions.openMovieId {
    //     dependencies.quickActions.openMovieId = nil
    // }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case searchMovies(_ query: String = "")
        // case openMovie(tmdbId: Movie.TMDBID)

        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .searchMovies(let query):
                dependencies.quickActions.searchMovies(query)
            // case .openMovie(let tmbdId):
            //    dependencies.quickActions.openMovie(tmbdId)
            }
        }
    }
}

// [public] ruddarr://open
// [public] ruddarr://movies/search
// [public] ruddarr://movies/search/{query?}
extension QuickActions.Deeplink {
    init(url: URL) throws {
        let unsupportedURL = AppError("Unsupported URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw unsupportedURL
        }

        let action = (components.host ?? "") + (components.path.untrailingSlashIt ?? "")

        switch action {
        case "", "open":
            self = .openApp
        case "movies/search":
            self = .searchMovies()
        case _ where action.hasPrefix("movies/search/"):
            let components = action.components(separatedBy: "/")

            self = .searchMovies(components[2])

        // case _ where action.hasPrefix("movies/open"):
        //    guard let tmdbId = Int(action.components(separatedBy: "/")[2]) else {
        //        throw unsupportedURL
        //    }
        //
        //    self = .openMovie(tmdbId: tmdbId)
        default:
            throw unsupportedURL
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
            case .addMovie: dependencies.quickActions.searchMovies("")
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
