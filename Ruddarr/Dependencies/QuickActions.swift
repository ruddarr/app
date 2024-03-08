import SwiftUI
import Combine

/**
[public] ruddarr://open
[public] ruddarr://movies/search
[public] ruddarr://movies/search/{query?}
[private] ruddarr://movies/open/{id}
*/
struct QuickActions {
    let moviePublisher = PassthroughSubject<Movie.ID, Never>()

    var registerShortcutItems: () -> Void = {
        UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
    }

    var searchMovies: (String) -> Void = { query in
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesView.Path.search(query)])
    }

    func openMovie(_ id: Movie.ID) {
        dependencies.router.selectedTab = .movies
        dependencies.quickActions.moviePublisher.send(id)
    }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case openMovie(_ id: Movie.ID)
        case searchMovies(_ query: String = "")

        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .searchMovies(let query):
                dependencies.quickActions.searchMovies(query)
            case .openMovie(let id):
                dependencies.quickActions.openMovie(id)
            }
        }
    }
}

extension QuickActions.Deeplink {
    init(url: URL) throws {
        let unsupportedURL = AppError(String(localized: "Unsupported URL: \(url.absoluteString)"))

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw unsupportedURL
        }

        let action = (components.host ?? "") + (components.path.untrailingSlashIt ?? "")
        let value = action.components(separatedBy: "/").last ?? ""

        switch action {
        case "", "open":
            self = .openApp
        case "movies/search":
            self = .searchMovies()
        case _ where action.hasPrefix("movies/search/"):
            self = .searchMovies(value)
        case _ where action.hasPrefix("movies/open/"):
            guard let tmdbId = Movie.ID(value) else { throw unsupportedURL }
            self = .openMovie(tmdbId)
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
            case .addMovie: String(localized: "Add New Movie")
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
