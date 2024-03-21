import Foundation

struct Series: Identifiable, Codable {
    let id: Int

    let title: String
    let sortTitle: String
    // cleanTitle
    // alternateTitles

    let tvdbID: Int?
    let tvRageID: Int?
    let tvMazeID: Int?
    let imdbID: String?

    let status: SeriesStatus
    let seriesType: SeriesType

    let path: String
    let qualityProfileID: Int?
    var rootFolderPath: String?
    let certification: String?

    let year: Int
    let ended: Bool
    let seasonFolder: Bool
    let useSceneNumbering: Bool

    let added: Date
    let firstAired: Date?
    let lastAired: Date?

    let monitored: Bool
    let monitorNewItems: SeriesMonitorNewItems

    let overview: String?
    let network: String?

    let originalLanguage: SeriesLanguage

    let seasons: [Season]
    let genres: [String]

    // runtime
    // ratings
    // statistics
}

enum SeriesStatus: String, Codable {
    case continuing
    case ended
    case upcoming
    case deleted

    var label: String {
        switch self {
        case .continuing: String(localized: "Continuing")
        case .ended: String(localized: "Ended")
        case .upcoming: String(localized: "Upcoming")
        case .deleted: String(localized: "Deleted")
        }
    }
}

enum SeriesType: String, Codable {
    case standard
    case daily
    case anime

    var label: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .daily: String(localized: "Daily")
        case .anime: String(localized: "Anime")
        }
    }
}

struct SeriesLanguage: Codable {
    let id: Int
    let name: String?
}

enum SeriesMonitorNewItems: String, Codable {
    case all
    case none
}

struct Season: Codable {
    let seasonNumber: Int
    let monitored: Bool
    let statistics: SeasonStatistics

    struct SeasonStatistics: Codable {
        let seasonCount: Int?
        let episodeFileCount: Int
        let episodeCount: Int
        let totalEpisodeCount: Int
        let percentOfEpisodes: Float
        let releaseGroups: [String]
    }
}
