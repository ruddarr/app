import SwiftUI

struct Series: Identifiable, Codable {
    // series only have an `id` after being added
    var id: Int { guid ?? (tvdbId + 100_000) }

    // the remapped `id` field
    var guid: Int?

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let title: String
    let sortTitle: String
    // cleanTitle
    // alternateTitles

    let tvdbId: Int
    let tvRageId: Int?
    let tvMazeId: Int?
    let imdbId: String?

    let status: SeriesStatus
    let seriesType: SeriesType

    let path: String
    let qualityProfileId: Int?
    var rootFolderPath: String?
    let certification: String?

    let year: Int
    var sortYear: Int { year == 0 ? 2100 : year }
    let runtime: Int
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

    let alternateTitles: [AlternateMovieTitle]
    var alternateTitlesString: String?

    mutating func setAlternateTitlesString() {
        alternateTitlesString = alternateTitles.map { $0.title }.joined(separator: " ")
    }

    let seasons: [Season]
    let genres: [String]
    let images: [MovieImage]
    let statistics: SeriesStatistics?

    // TODO: ratings

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case title
        case sortTitle
        case tvdbId
        case tvRageId
        case tvMazeId
        case imdbId
        case status
        case seriesType
        case path
        case qualityProfileId
        case rootFolderPath
        case certification
        case year
        case runtime
        case ended
        case seasonFolder
        case useSceneNumbering
        case added
        case firstAired
        case lastAired
        case monitored
        case monitorNewItems
        case overview
        case network
        case originalLanguage
        case alternateTitles
        case seasons
        case genres
        case images
    }

    var exists: Bool {
        guid != nil
    }

    var isDownloaded: Bool {
        // TODO: needs logic
        false
    }

    var isWaiting: Bool {
        // TODO: needs logic
        false
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var genreLabel: String {
        genres.formatted(.list(type: .and, width: .narrow))
    }

    // TODO: needs work
    var stateLabel: LocalizedStringKey {
//        if isDownloaded {
//            return "Downloaded"
//        }
//
//        if isWaiting {
//            return "Waiting"
//        }
//
//        if monitored && isAvailable {
//            return "Missing"
//        }

        return "Unwanted"
    }

    var runtimeLabel: String? {
        guard runtime > 0 else { return nil }

        let hours = runtime / 60
        let minutes = runtime % 60

        return hours == 0
            ? String(format: String(localized: "%dm", comment: "%d = minutes (13m)"), minutes)
            : String(format: String(localized: "%dh %dm", comment: "$1 = hours, $2 = minutes (1h 13m)"), hours, minutes)
    }

    var certificationLabel: String {
        guard let rating = certification else {
            return String(localized: "Unrated")
        }

        if rating.isEmpty || rating == "0" {
            return String(localized: "Unrated")
        }

        return rating
    }
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

struct SeriesLanguage: Codable {
    let id: Int
    let name: String?
}

struct SeriesStatistics: Codable {
    let episodeFileCount: Int
    let episodeCount: Int
    let totalEpisodeCount: Int
    let sizeOnDisk: Int
    let releaseGroups: [String]
    let percentOfEpisodes: Double
    let previousAiring, nextAiring: Date?
    let seasonCount: Int?
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
