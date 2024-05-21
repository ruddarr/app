import SwiftUI

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

    let originalLanguage: MediaLanguage

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

    var label: LocalizedStringKey {
        switch self {
        case .continuing: "Continuing"
        case .ended: "Ended"
        case .upcoming: "Upcoming"
        case .deleted: "Deleted"
        }
    }
}

enum SeriesType: String, Codable {
    case standard
    case daily
    case anime

    var label: LocalizedStringKey {
        switch self {
        case .standard: "Standard"
        case .daily: "Daily"
        case .anime: "Anime"
        }
    }
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
