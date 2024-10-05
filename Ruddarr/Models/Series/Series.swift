import SwiftUI
import CoreSpotlight

struct Series: Media, Identifiable, Equatable, Codable {
    // series only have an `id` after being added
    var id: Int { guid ?? (tvdbId + 100_000) }

    // the remapped `id` field
    var guid: Int?

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let title: String
    let titleSlug: String?
    let sortTitle: String

    let tvdbId: Int
    let tvRageId: Int?
    let tvMazeId: Int?
    let imdbId: String?
    let tmdbId: Int?

    let status: SeriesStatus
    var seriesType: SeriesType

    let path: String?
    let folder: String?
    var qualityProfileId: Int?
    var rootFolderPath: String?
    let certification: String?

    let year: Int
    let runtime: Int
    let airTime: String?
    let ended: Bool
    var seasonFolder: Bool
    let useSceneNumbering: Bool

    let added: Date
    let firstAired: Date?
    let lastAired: Date?
    let nextAiring: Date?
    let previousAiring: Date?

    var monitored: Bool
    var monitorNewItems: SeriesMonitorNewItems?

    let overview: String?
    let network: String?

    let originalLanguage: MediaLanguage?

    let alternateTitles: [MediaAlternateTitle]?

    var seasons: [Season]

    let genres: [String]
    let images: [MediaImage]
    let ratings: SeriesRatings?
    let statistics: SeriesStatistics?

    var addOptions: SeriesAddOptions?

    // Sonarr v3
    let languageProfileId: Int = 1

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case title
        case titleSlug
        case sortTitle
        case tvdbId
        case tvRageId
        case tvMazeId
        case imdbId
        case tmdbId
        case status
        case seriesType
        case path
        case folder
        case qualityProfileId
        case rootFolderPath
        case certification
        case year
        case runtime
        case airTime
        case ended
        case seasonFolder
        case useSceneNumbering
        case added
        case firstAired
        case lastAired
        case nextAiring
        case previousAiring
        case monitored
        case monitorNewItems
        case overview
        case network
        case originalLanguage
        case alternateTitles
        case seasons
        case genres
        case images
        case ratings
        case statistics
        case addOptions
        case languageProfileId
    }

    var exists: Bool {
        guid != nil
    }

    var popularity: Float {
        guard let votes = ratings?.votes, votes > 0 else { return 0 }
        guard let rating = ratings?.value else { return 0 }

        return rating * log(Float(votes) + 1)
    }

    var sortYear: TimeInterval {
        if let date = firstAired { return date.timeIntervalSince1970 }
        if year <= 0 { return Date.distantFuture.timeIntervalSince1970 }

        return DateComponents(calendar: .current, year: year).date?.timeIntervalSince1970
            ?? Date.distantFuture.timeIntervalSince1970
    }

    var isDownloaded: Bool {
        (statistics?.percentOfEpisodes ?? 0) >= 100
    }

    var isWaiting: Bool {
        if let premiere = firstAired { return premiere > Date.now }
        return status == .upcoming || year == 0 || seasons.isEmpty
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var genreLabel: String {
        genres.prefix(3)
            .map { $0.replacingOccurrences(of: "Science Fiction", with: "Sci-Fi") }
            .formattedList()
    }

    var stateLabel: LocalizedStringKey {
        if isDownloaded {
            return "Downloaded"
        }

        if isWaiting {
            return "Unreleased"
        }

        if monitored && percentOfEpisodes < 100 {
            return episodeFileCount == 0 ? "Missing" : "Missing Episodes"
        }

        return "Unwanted"
    }

    var yearLabel: String {
        year > 0 ? String(year) : String(localized: "TBA")
    }

    var runtimeLabel: String? {
        guard runtime > 0 else { return nil }
        return formatRuntime(runtime)
    }

    var sizeLabel: String? {
        guard let bytes = statistics?.sizeOnDisk, bytes > 0 else { return nil }
        return formatBytes(bytes)
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

    var seasonCount: Int {
        seasons.filter { $0.seasonNumber != 0 }.count
    }

    var episodeCount: Int {
        statistics?.episodeCount ?? 0
    }

    var episodeFileCount: Int {
        statistics?.episodeFileCount ?? 0
    }

    var percentOfEpisodes: Float {
        statistics?.percentOfEpisodes ?? 0
    }

    func seasonById(_ id: Season.ID) -> Season? {
        seasons.first { $0.id == id }
    }

    func alternateTitlesString() -> String? {
        alternateTitles?.map { $0.title }.joined(separator: " ")
    }
}

extension Series {
    func searchableItem(poster: URL?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.movie)
        attributes.title = title
        attributes.genre = genres.first
        attributes.addedDate = added
        attributes.thumbnailURL = poster
        attributes.contentRating = NSNumber(value: certification == "R")
        attributes.userCurated = NSNumber(value: monitored)
        attributes.userOwned = NSNumber(value: (statistics?.percentOfEpisodes ?? 0) > 0)

        attributes.contentDescription = [yearLabel, runtimeLabel, String(localized: "\(seasonCount) Seasons")]
            .compactMap { $0 }
            .joined(separator: " · ")

        if let titles = alternateTitles {
            attributes.keywords = titles
                .filter { $0.title == title }
                .map { $0.title }
        }

        return CSSearchableItem(
            uniqueIdentifier: "series:\(id):\(instanceId?.uuidString ?? "")",
            domainIdentifier: instanceId?.uuidString,
            attributeSet: attributes
        )
    }

    var searchableHash: String {
        "\(id):\(sortTitle):\(year):\(runtime):\(seasonCount)"
    }
}

enum SeriesStatus: String, Equatable, Codable {
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

    var icon: Image {
        switch self {
        case .continuing: Image(systemName: "play.fill")
        case .ended: Image(systemName: "stop.fill")
        case .upcoming: Image(systemName: "clock")
        case .deleted: Image(systemName: "xmark.circle")
        }
    }
}

enum SeriesType: String, Equatable, Codable, Identifiable, CaseIterable {
    var id: Self { self }

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

struct SeriesRatings: Equatable, Codable {
    let votes: Int
    let value: Float
}

struct SeriesStatistics: Equatable, Codable {
    let sizeOnDisk: Int
    let seasonCount: Int
    let episodeCount: Int
    let episodeFileCount: Int
    let totalEpisodeCount: Int
    let percentOfEpisodes: Float
}

enum SeriesMonitorNewItems: String, Equatable, Codable {
    case all
    case none
}

struct SeriesAddOptions: Equatable, Codable {
    var monitor: SeriesMonitorType
}

enum SeriesMonitorType: String, Codable, Identifiable, CaseIterable {
    var id: Self { self }

    case unknown
    case all
    case future
    case missing
    case existing
    case firstSeason
    case lastSeason
    case latestSeason // obsolete
    case pilot
    case recent
    case monitorSpecials
    case unmonitorSpecials
    case none
    case skip

    var label: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .all: String(localized: "All Episodes")
        case .future: String(localized: "Future Episodes")
        case .missing: String(localized: "Missing Episodes")
        case .existing: String(localized: "Existing Episodes")
        case .recent: String(localized: "Recent Episodes")
        case .pilot: String(localized: "Pilot Episode")
        case .firstSeason: String(localized: "First Season")
        case .lastSeason: String(localized: "Last Season")
        case .latestSeason: ""
        case .monitorSpecials: String(localized: "Monitor Specials")
        case .unmonitorSpecials: String(localized: "Unmonitor Specials")
        case .none: String(localized: "None")
        case .skip: ""
        }
    }
}

struct SeriesEditorResource: Codable {
    let seriesIds: [Int]
    let monitored: Bool?
    let monitorNewItems: SeriesMonitorNewItems
    let seriesType: SeriesType
    let seasonFolder: Bool?
    let qualityProfileId: Int?
    let rootFolderPath: String?
    let moveFiles: Bool?
}

extension Series {
    static var void: Self {
        .init(
            title: "", titleSlug: nil, sortTitle: "", tvdbId: 0, tvRageId: nil, tvMazeId: nil, imdbId: nil, tmdbId: nil, status: .deleted, seriesType: .standard,
            path: nil, folder: nil, certification: nil, year: 0, runtime: 0, airTime: nil, ended: false, seasonFolder: false, useSceneNumbering: false, added: Date.now,
            firstAired: nil, lastAired: nil, nextAiring: nil, previousAiring: nil, monitored: false, overview: nil, network: nil,
            originalLanguage: MediaLanguage(id: 0, name: nil), alternateTitles: nil, seasons: [], genres: [], images: [], ratings: nil, statistics: nil
        )
    }
}
