import SwiftUI
import Combine

/**
[public] ruddarr://open
[public] ruddarr://calendar
[public] ruddarr://activity
[public] ruddarr://movies
[public] ruddarr://movies/search
[public] ruddarr://movies/search/{query?}
[private] ruddarr://movies/open/{id}?instance={instance?}
[public] ruddarr://series
[public] ruddarr://series/search
[public] ruddarr://series/search/{query?}
[private] ruddarr://series/open/{id}?instance={instance?}
[private] ruddarr://series/open/{id}/?season={id}&instance={instance?}
*/
struct QuickActions {
    let moviePublisher = PassthroughSubject<Movie.ID, Never>()
    var moviePublisherPending: Movie.ID?

    let seriesPublisher = PassthroughSubject<(Series.ID, Season.ID?), Never>()
    var seriesPublisherPending: (Series.ID, Season.ID?)?

    var registerShortcutItems: () -> Void = {
        #if os(iOS)
            UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
        #endif
    }

    var openCalendar: () -> Void = {
        dependencies.router.selectedTab = .calendar
    }

    var openActivity: () -> Void = {
        dependencies.router.selectedTab = .activity
    }

    var openMovies: () -> Void = {
        dependencies.router.selectedTab = .movies
    }

    var openMovieSearch: (String) -> Void = { query in
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesPath.search(query)])
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

    var openSeries: () -> Void = {
        dependencies.router.selectedTab = .series
    }

    var openSeriesSearch: (String) -> Void = { query in
        dependencies.router.selectedTab = .series
        dependencies.router.seriesPath = .init([SeriesPath.search(query)])
    }

    func openSeriesItem(_ id: Series.ID, _ instance: Instance.ID?) {
        if let instanceId = instance {
            dependencies.router.switchToSonarrInstance = instanceId
        }

        dependencies.router.selectedTab = .series
        dependencies.router.seriesPath = .init()

        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000)
            dependencies.quickActions.seriesPublisherPending = (id, nil)
            dependencies.quickActions.seriesPublisher.send((id, nil))
        }
    }

    func openSeriesSeason(_ id: Series.ID, _ season: Season.ID, _ instance: Instance.ID?) {
        if let instanceId = instance {
            dependencies.router.switchToSonarrInstance = instanceId
        }

        dependencies.router.selectedTab = .series
        dependencies.router.seriesPath = .init()

        Task { @MainActor in
            try await Task.sleep(nanoseconds: 100_000_000)
            dependencies.quickActions.seriesPublisherPending = (id, season)
            dependencies.quickActions.seriesPublisher.send((id, season))
        }
    }

    func reset() {
        dependencies.quickActions.moviePublisherPending = nil
        dependencies.quickActions.seriesPublisherPending = nil
    }

    func pending() {
        if let movieId = dependencies.quickActions.moviePublisherPending {
            dependencies.quickActions.moviePublisher.send(movieId)
        }

        if let seriesId = dependencies.quickActions.seriesPublisherPending {
            dependencies.quickActions.seriesPublisher.send(seriesId)
        }
    }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case openCalendar
        case openActivity
        case openMovies
        case openMovie(_ id: Movie.ID, _ instance: Instance.ID?)
        case addMovie(_ query: String = "")
        case openSeries
        case openSeriesItem(_ id: Series.ID, _ instance: Instance.ID?)
        case openSeriesSeason(_ id: Movie.ID, _ season: Season.ID, _ instance: Instance.ID?)
        case addSeries(_ query: String = "")

        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .openCalendar:
                dependencies.quickActions.openCalendar()
            case .openActivity:
                dependencies.quickActions.openCalendar()
            case .openMovies:
                dependencies.quickActions.openMovies()
            case .addMovie(let query):
                dependencies.quickActions.openMovieSearch(query)
            case .openMovie(let movie, let instance):
                dependencies.quickActions.openMovie(movie, instance)
            case .openSeries:
                dependencies.quickActions.openSeries()
            case .addSeries(let query):
                dependencies.quickActions.openSeriesSearch(query)
            case .openSeriesItem(let series, let instance):
                dependencies.quickActions.openSeriesItem(series, instance)
            case .openSeriesSeason(let series, let season, let instance):
                dependencies.quickActions.openSeriesSeason(series, season, instance)
            }
        }
    }
}

extension QuickActions.Deeplink {
    // swiftlint:disable cyclomatic_complexity
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
        case "activity":
            self = .openActivity
        case "movies":
            self = .openMovies
        case "movies/search":
            self = .addMovie()
        case _ where action.hasPrefix("movies/search/"):
            self = .addMovie(value)
        case _ where action.hasPrefix("movies/open/"):
            guard let tmdbId = Movie.ID(value) else { throw unsupportedURL }
            let instanceId = components.queryItems?.first(where: { $0.name == "instance" })?.value
            self = .openMovie(tmdbId, instanceId == nil ? nil : UUID(uuidString: instanceId!))
        case "series":
            self = .openMovies
        case "series/search":
            self = .addSeries()
        case _ where action.hasPrefix("series/search/"):
            self = .addSeries(value)
        case _ where action.hasPrefix("series/open/"):
            guard let tvdbId = Series.ID(value) else { throw unsupportedURL }
            let seasonId = components.queryItems?.first(where: { $0.name == "season" })?.value
            let instanceId = components.queryItems?.first(where: { $0.name == "instance" })?.value

            if let id = seasonId, let season = Int(id) {
                self = .openSeriesSeason(tvdbId, season, instanceId == nil ? nil : UUID(uuidString: instanceId!))
            } else {
                self = .openSeriesItem(tvdbId, instanceId == nil ? nil : UUID(uuidString: instanceId!))
            }
        default:
            throw unsupportedURL
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

#if os(iOS)
extension QuickActions {
    enum ShortcutItem: String, CaseIterable {
        case addMovie
        case addSeries

        var title: String {
            switch self {
            case .addMovie: String(localized: "Add Movie")
            case .addSeries: String(localized: "Add Series")
            }
        }

        var icon: UIApplicationShortcutIcon {
            switch self {
            case .addMovie: UIApplicationShortcutIcon(type: .add)
            case .addSeries: UIApplicationShortcutIcon(type: .add)
            }
        }

        func callAsFunction() {
            switch self {
            case .addMovie: dependencies.quickActions.openMovieSearch("")
            case .addSeries: dependencies.quickActions.openSeriesSearch("")
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
#endif
