import SwiftUI
import Combine

// TODO: add missing series actions

/**
[public] ruddarr://open
[public] ruddarr://calendar
[public] ruddarr://movies
[public] ruddarr://movies/search
[public] ruddarr://movies/search/{query?}
[private] ruddarr://movies/open/{id}?instance={instance?}
*/
struct QuickActions {
    let moviePublisher = PassthroughSubject<Movie.ID, Never>()
    var moviePublisherPending: Movie.ID?

    let seriesPublisher = PassthroughSubject<Movie.ID, Never>()
    var seriesPublisherPending: Movie.ID?

    var registerShortcutItems: () -> Void = {
        UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
    }

    var openCalendar: () -> Void = {
        dependencies.router.selectedTab = .calendar
    }

    var openMovies: () -> Void = {
        dependencies.router.selectedTab = .movies
    }

    var searchMovies: (String) -> Void = { query in
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesView.Path.search(query)])
    }

    func openMovie(_ id: Movie.ID, _ instance: Instance.ID?) {
        if let instanceId = instance {
            dependencies.router.switchToRadarrInstance = instanceId
        }

        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init()

        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000)
            dependencies.quickActions.moviePublisherPending = id
            dependencies.quickActions.moviePublisher.send(id)
        }
    }

    func reset() {
        dependencies.quickActions.moviePublisherPending = nil
    }

    func pending() {
        if let movieId = dependencies.quickActions.moviePublisherPending {
            dependencies.quickActions.moviePublisher.send(movieId)
        }
    }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case openCalendar
        case openMovies
        case openMovie(_ id: Movie.ID, _ instance: Instance.ID?)
        case searchMovies(_ query: String = "")

        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .openCalendar:
                dependencies.quickActions.openCalendar()
            case .openMovies:
                dependencies.quickActions.openMovies()
            case .searchMovies(let query):
                dependencies.quickActions.searchMovies(query)
            case .openMovie(let movie, let instance):
                dependencies.quickActions.openMovie(movie, instance)
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
        case "calendar":
            self = .openCalendar
        case "movies":
            self = .openMovies
        case "movies/search":
            self = .searchMovies()
        case _ where action.hasPrefix("movies/search/"):
            self = .searchMovies(value)
        case _ where action.hasPrefix("movies/open/"):
            guard let tmdbId = Movie.ID(value) else { throw unsupportedURL }
            let instanceId = components.queryItems?.first(where: { $0.name == "instance" })?.value
            self = .openMovie(tmdbId, instanceId == nil ? nil : UUID(uuidString: instanceId!))
        default:
            throw unsupportedURL
        }
    }
}

extension QuickActions {
    enum ShortcutItem: String, CaseIterable {
        case calendar
        case addMovie

        var title: String {
            switch self {
            case .calendar: String(localized: "Calendar")
            case .addMovie: String(localized: "Add Movie")
            }
        }

        var icon: UIApplicationShortcutIcon {
            switch self {
            case .calendar: UIApplicationShortcutIcon(type: .date)
            case .addMovie: UIApplicationShortcutIcon(type: .add)
            }
        }

        func callAsFunction() {
            switch self {
            case .calendar: dependencies.quickActions.openCalendar()
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
