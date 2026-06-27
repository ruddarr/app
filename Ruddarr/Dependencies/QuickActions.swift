import SwiftUI
import Combine

/**
[public] ruddarr://open
[public] ruddarr://calendar
[public] ruddarr://activity
[public] ruddarr://movies
[public] ruddarr://movies/search
[public] ruddarr://movies/search/{query?}
[private] ruddarr://movies/open/{id}?instance={instanceIdOrName?}
[public] ruddarr://series
[public] ruddarr://series/search
[public] ruddarr://series/search/{query?}
[private] ruddarr://series/open/{id}?instance={instanceIdOrName?}
[private] ruddarr://series/open/{id}/?season={seasonId}&episode={episodeId}&instance={instanceIdOrName?}
*/
@MainActor
final class QuickActions {
    nonisolated init() {}

    let moviePublisher = PassthroughSubject<Movie.ID, Never>()
    var moviePublisherPending: Movie.ID?

    let seriesPublisher = PassthroughSubject<(Series.ID, Season.ID?, Episode.ID?), Never>()
    var seriesPublisherPending: (Series.ID, Season.ID?, Episode.ID?)?

    private var timer: Timer?

    var registerShortcutItems: @MainActor () -> Void = {
        #if os(iOS)
            UIApplication.shared.shortcutItems = ShortcutItem.allCases.map(\.shortcutItem)
        #endif
    }

    var openCalendar: @MainActor () -> Void = {
        dependencies.router.selectedTab = .calendar
    }

    var openActivity: @MainActor () -> Void = {
        dependencies.router.selectedTab = .activity
    }

    var openMovies: @MainActor () -> Void = {
        dependencies.router.selectedTab = .movies
    }

    var openMovieSearch: @MainActor (String) -> Void = { query in
        var searchText: String = query

        if let imdb = extractImdbId(query) {
            searchText = "imdb:\(imdb)"
        }

        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init([MoviesPath.search(searchText)])
    }

    func openMovie(_ id: Movie.ID, _ instance: String?) {
        dependencies.router.switchToRadarrInstance = instance
        dependencies.router.selectedTab = .movies
        dependencies.router.moviesPath = .init()

        dependencies.quickActions.moviePublisherPending = id

        dependencies.quickActions.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                if let id = dependencies.quickActions.moviePublisherPending {
                    dependencies.quickActions.moviePublisher.send(id)
                } else {
                    dependencies.quickActions.clearTimer()
                }
            }
        }
    }

    var openSeriesSearch: @MainActor (String) -> Void = { query in
        var searchText: String = query

        if let imdb = extractImdbId(query) {
            searchText = "imdb:\(imdb)"
        }

        dependencies.router.selectedTab = .series
        dependencies.router.seriesPath = .init([SeriesPath.search(searchText)])
    }

    func openSeries(_ id: Series.ID, _ season: Season.ID?, _ episode: Episode.ID?, _ instance: String?) {
        dependencies.router.switchToSonarrInstance = instance
        dependencies.router.selectedTab = .series
        dependencies.router.seriesPath = .init()

        dependencies.quickActions.seriesPublisherPending = (id, season, episode)

        dependencies.quickActions.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated {
                if let ids = dependencies.quickActions.seriesPublisherPending {
                    dependencies.quickActions.seriesPublisher.send(ids)
                } else {
                    dependencies.quickActions.clearTimer()
                }
            }
        }
    }

    func clearTimer() {
        dependencies.quickActions.timer?.invalidate()
        dependencies.quickActions.timer = nil

        dependencies.quickActions.moviePublisherPending = nil
        dependencies.quickActions.seriesPublisherPending = nil
    }
}

extension QuickActions {
    enum Deeplink {
        case openApp
        case openCalendar
        case openActivity
        case openMovies
        case openMovie(_ id: Movie.ID, _ instance: String?)
        case addMovie(_ query: String = "")
        case openSeries(_ id: Series.ID, _ instance: String?)
        case openSeason(_ id: Series.ID, _ season: Season.ID, _ instance: String?)
        case openEpisode(_ id: Series.ID, _ season: Season.ID, _ episode: Episode.ID, _ instance: String?)
        case addSeries(_ query: String = "")

        @MainActor
        func callAsFunction() {
            switch self {
            case .openApp:
                break
            case .openCalendar:
                dependencies.quickActions.openCalendar()
            case .openActivity:
                dependencies.quickActions.openActivity()
            case .openMovies:
                dependencies.quickActions.openMovies()
            case .addMovie(let query):
                dependencies.quickActions.openMovieSearch(query)
            case .openMovie(let movie, let instance):
                dependencies.quickActions.openMovie(movie, instance)
            case .openSeries(let id, let instance):
                dependencies.quickActions.openSeries(id, nil, nil, instance)
            case .openSeason(let id, let season, let instance):
                dependencies.quickActions.openSeries(id, season, nil, instance)
            case .openEpisode(let id, let season, let episode, let instance):
                dependencies.quickActions.openSeries(id, season, episode, instance)
            case .addSeries(let query):
                dependencies.quickActions.openSeriesSearch(query)
            }
        }
    }
}

extension QuickActions.Deeplink {
    // swiftlint:disable:next cyclomatic_complexity
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
            guard let id = Movie.ID(value) else { throw unsupportedURL }
            let instance = components.queryItems?.first { $0.name == "instance" }?.value
            self = .openMovie(id, instance)
        case "series":
            self = .openMovies
        case "series/search":
            self = .addSeries()
        case _ where action.hasPrefix("series/search/"):
            self = .addSeries(value)
        case _ where action.hasPrefix("series/open/"):
            guard let id = Series.ID(value) else { throw unsupportedURL }
            let season = (components.queryItems?.first { $0.name == "season" }?.value).flatMap { Int($0) }
            let episode = (components.queryItems?.first { $0.name == "episode" }?.value).flatMap { Int($0) }
            let instance = components.queryItems?.first { $0.name == "instance" }?.value

            if let season, let episode {
                self = .openEpisode(id, season, episode, instance)
            } else if let season {
                self = .openSeason(id, season, instance)
            } else {
                self = .openSeries(id, instance)
            }
        default:
            throw unsupportedURL
        }
    }

    var url: URL? {
        switch self {
        case .openMovie(let id, let instance):
            URL(string: "ruddarr://movies/open/\(id)?instance=\(instance ?? "")")
        case .openSeries(let id, let instance):
            URL(string: "ruddarr://series/open/\(id)?instance=\(instance ?? "")")
        case .openSeason(let id, let season, let instance):
            URL(string: "ruddarr://series/open/\(id)?season=\(season)&instance=\(instance ?? "")")
        case .openEpisode(let id, let season, let episode, let instance):
            URL(string: "ruddarr://series/open/\(id)?season=\(season)&episode=\(episode)&instance=\(instance ?? "")")
        default:
            nil
        }
    }
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

        @MainActor
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
