import SwiftUI
import Combine
import AppIntents

@Observable
class Router {
    var selectedTab: TabItem = .movies

    var switchToRadarrInstance: String?
    var switchToSonarrInstance: String?

    var moviesPath: NavigationPath = .init()
    var seriesPath: NavigationPath = .init()
    var calendarPath: NavigationPath = .init()
    var settingsPath: NavigationPath = .init()
    var mediaSheetRoute: MediaSheetRoute?
    var mediaSheetPath: NavigationPath = .init()

    func reset() {
        moviesPath = .init()
        seriesPath = .init()
        calendarPath = .init()
        mediaSheetRoute = nil
        mediaSheetPath = .init()
    }

    func presentMovie(_ movie: Movie) {
        mediaSheetPath = .init()
        mediaSheetRoute = .movie(movie)
    }

    func presentSeries(_ series: Series) {
        mediaSheetPath = .init()
        mediaSheetRoute = .series(series)
    }

    func presentEpisode(_ episode: Episode, grouped: Bool) {
        let route = MediaSheetRoute.episode(episode, grouped: grouped)
        mediaSheetPath = route.initialPath
        mediaSheetRoute = route
    }

    func dismissMediaSheet() {
        mediaSheetRoute = nil
        mediaSheetPath = .init()
    }
}

struct MediaSheetRoute: Identifiable {
    enum Kind {
        case movie
        case series
    }

    let id: String
    let kind: Kind
    let movieId: Movie.ID?
    let seriesId: Series.ID?
    let seasonId: Season.ID?
    let episodeId: Episode.ID?
    let instanceId: Instance.ID?
    let movie: Movie?
    let series: Series?
    let episode: Episode?

    static func movie(_ movie: Movie) -> Self {
        .init(
            id: "movie-\(movie.id)-\(movie.instanceId?.uuidString ?? "unknown")",
            kind: .movie,
            movieId: movie.id,
            seriesId: nil,
            seasonId: nil,
            episodeId: nil,
            instanceId: movie.instanceId,
            movie: movie,
            series: nil,
            episode: nil
        )
    }

    static func series(_ series: Series) -> Self {
        .init(
            id: "series-\(series.id)-\(series.instanceId?.uuidString ?? "unknown")",
            kind: .series,
            movieId: nil,
            seriesId: series.id,
            seasonId: nil,
            episodeId: nil,
            instanceId: series.instanceId,
            movie: nil,
            series: series,
            episode: nil
        )
    }

    static func episode(_ episode: Episode, grouped: Bool) -> Self {
        .init(
            id: "series-\(episode.seriesId)-\(episode.id)-\(episode.instanceId?.uuidString ?? "unknown")",
            kind: .series,
            movieId: nil,
            seriesId: episode.seriesId,
            seasonId: episode.seasonNumber,
            episodeId: grouped ? nil : episode.id,
            instanceId: episode.instanceId,
            movie: nil,
            series: nil,
            episode: episode
        )
    }

    var initialPath: NavigationPath {
        var path = NavigationPath()

        guard kind == .series, let seriesId, let seasonId else {
            return path
        }

        path.append(SeriesPath.season(seriesId, seasonId, nil))

        if let episodeId {
            path.append(SeriesPath.episode(seriesId, episodeId))
        }

        return path
    }
}

enum TabItem: String, Identifiable, Hashable, Sendable {
    var id: Self { self }

    case movies
    case series
    case calendar
    case activity

    #if os(macOS)
        case history
    #endif

    case settings

    enum Openable: String, CaseIterable {
        case movies
        case series
        case calendar
        case activity
    }

    var label: String {
        switch self {
        case .movies: String(localized: "Movies", comment: "Plural. Tab/sidebar menu item")
        case .series: String(localized: "Series", comment: "Plural. Tab/sidebar menu item")
        case .calendar: String(localized: "Calendar", comment: "Tab/sidebar menu item")
        case .activity: String(localized: "Activity", comment: "Tab/sidebar menu item")
        case .settings: String(localized: "Settings", comment: "Tab/sidebar menu item")

        #if os(macOS)
            case .history: String(localized: "History", comment: "Tab/sidebar menu item")
        #endif
        }
    }

    var icon: String {
        switch self {
        case .movies: "movies"
        case .series: "series"
        case .calendar: "calendar"
        case .activity: "waveform.path.ecg"
        case .settings: "gear"

        #if os(macOS)
            case .history: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        #endif
        }
    }

    var image: Image {
        switch self {
        case .movies, .series: Image(icon)
        default: Image(systemName: icon)
        }
    }
}

extension TabItem.Openable: AppEnum {
    var tab: TabItem {
        switch self {
        case .movies: .movies
        case .series: .series
        case .calendar: .calendar
        case .activity: .activity
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tab")

    static var caseDisplayRepresentations: [TabItem.Openable: DisplayRepresentation] {[
        .movies: DisplayRepresentation(
            title: "Movies",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "film")
        ),
        .series: DisplayRepresentation(
            title: "Series",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "tv")
        ),
        .calendar: DisplayRepresentation(
            title: "Calendar",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "calendar")
        ),
        .activity: DisplayRepresentation(
            title: "Activity",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "waveform.path.ecg")
        ),
    ]}
}
