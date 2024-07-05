import SwiftUI
import Foundation

// Changing instance properties is risky and can break cloud
// synchronization, extensively changes don't wipe instance data.
struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()

    // WARNING: BE CAREFUL CHANGING
    var type: InstanceType = .radarr
    var mode: InstanceMode = .normal
    var label: String = ""
    var url: String = ""
    var apiKey: String = ""
    var headers: [InstanceHeader] = []
    // WARNING: BE CAREFUL CHANGING

    var version: String = ""

    var rootFolders: [InstanceRootFolders] = []
    var qualityProfiles: [InstanceQualityProfile] = []

    var auth: [String: String] {
        var map: [String: String] = [:]

        map["X-Api-Key"] = apiKey

        for header in headers {
            map[header.name] = header.value
        }

        return map
    }

    func isPrivateIp() -> Bool {
        guard let instanceUrl = URL(string: url) else {
            return false
        }

        return isPrivateIpAddress(instanceUrl.host() ?? "")
    }

    func timeout(_ call: InstanceTimeout) -> Double {
        switch call {
        case .normal: 10
        case .slow: mode == .large ? 300 : 10
        case .releaseSearch: mode == .large ? 120 : 60
        case .releaseDownload: 15
        }
    }
}

enum InstanceType: String, Identifiable, CaseIterable, Codable {
    case radarr = "Radarr"
    case sonarr = "Sonarr"
    var id: Self { self }
}

enum InstanceMode: Codable {
    case normal
    case large
}

enum InstanceTimeout: Codable {
    case normal
    case slow
    case releaseSearch
    case releaseDownload
}

struct InstanceHeader: Equatable, Identifiable, Codable {
    var id = UUID()
    var name: String
    var value: String

    init(name: String = "", value: String = "") {
        self.name = name.replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct InstanceStatus: Codable {
    let appName: String
    let version: String
    let authentication: String
}

struct InstanceRootFolders: Identifiable, Equatable, Codable {
    let id: Int
    let accessible: Bool
    let path: String?
    let freeSpace: Int?

    var label: String {
        path?.untrailingSlashIt ?? "Folder (\(id))"
    }
}

struct InstanceQualityProfile: Identifiable, Equatable, Codable {
    let id: Int
    let name: String
}

struct DownloadReleaseCommand: Codable {
    let guid: String
    let indexerId: Int

    // Radarr
    var movieId: Int?

    // Sonarr (season)
    var seriesId: Int?
    var seasonNumber: Int?

    // Sonarr (episode)
    var episodeId: Int?

    init(guid: String, indexerId: Int, movieId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.movieId = movieId
    }

    init(guid: String, indexerId: Int, seriesId: Int?, seasonId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.seriesId = seriesId
        self.seasonNumber = seasonId
    }

    init(guid: String, indexerId: Int, episodeId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.episodeId = episodeId
    }
}

enum RadarrCommand {
    case refresh(_ ids: [Movie.ID])
    case search(_ ids: [Movie.ID])

    var payload: Payload {
        switch self {
        case .refresh(let ids):
            Payload(name: "RefreshMovie", movieIds: ids)
        case .search(let ids):
            Payload(name: "MoviesSearch", movieIds: ids)
        }
    }

    struct Payload: Encodable {
        let name: String
        let movieIds: [Int]
    }
}

enum SonarrCommand {
    case refresh(_ series: Series.ID)
    case seriesSearch(_ series: Series.ID)
    case seasonSearch(_ series: Series.ID, season: Season.ID)
    case episodeSearch(_ ids: [Episode.ID])

    var payload: Payload {
        switch self {
        case .refresh(let series):
            Payload(name: "RefreshSeries", seriesId: series)
        case .seriesSearch(let series):
            Payload(name: "SeriesSearch", seriesId: series)
        case .seasonSearch(let series, let season):
            Payload(name: "SeasonSearch", seriesId: series, seasonNumber: season)
        case .episodeSearch(let ids):
            Payload(name: "EpisodeSearch", episodeIds: ids)
        }
    }

    struct Payload: Encodable {
        let name: String
        let seriesId: Int?
        let seasonNumber: Int?
        let episodeIds: [Int]?

        init(name: String, seriesId: Int? = nil, seasonNumber: Int? = nil, episodeIds: [Int]? = nil) {
            self.name = name
            self.seriesId = seriesId
            self.seasonNumber = seasonNumber
            self.episodeIds = episodeIds
        }
    }
}

extension Instance {
    static var radarrVoid: Self {
        .init(
            id: UUID(uuidString: "00000000-1000-0000-0000-000000000000")!,
            type: .radarr
        )
    }

    static var sonarrVoid: Self {
        .init(
            id: UUID(uuidString: "00000000-2000-0000-0000-000000000000")!,
            type: .sonarr
        )
    }

    static var radarrDummy: Self {
        .init(
            id: UUID(uuidString: "00000000-2000-0000-0000-000000000000")!,
            type: .radarr,
            label: ".radarr",
            url: "http://10.0.1.5:8310",
            apiKey: "3b0600c1b3aa42bfb0222f4e13a81f39",
            rootFolders: [
                InstanceRootFolders(id: 1, accessible: true, path: "/volume1/Media/Movies", freeSpace: 1_000_000_000),
            ],
            qualityProfiles: [
                InstanceQualityProfile(id: 1, name: "Any"),
                InstanceQualityProfile(id: 2, name: "4K"),
            ]
        )
    }

    static var sonarrDummy: Self {
        .init(
            id: UUID(uuidString: "00000000-4000-0000-0000-000000000000")!,
            type: .sonarr,
            label: ".sonarr",
            url: "http://10.0.1.5:8989",
            apiKey: "f8e3682b3b984cddbaa00047a09d0fbd",
            rootFolders: [
                InstanceRootFolders(id: 1, accessible: true, path: "/volume1/Media/TV Series", freeSpace: 2_000_000_000),
                InstanceRootFolders(id: 2, accessible: true, path: "/volume2/Media/Docuseries", freeSpace: 2_000_000_000),
            ],
            qualityProfiles: [
                InstanceQualityProfile(id: 1, name: "Any"),
                InstanceQualityProfile(id: 2, name: "SD"),
                InstanceQualityProfile(id: 3, name: "720p"),
                InstanceQualityProfile(id: 4, name: "1080p"),
                InstanceQualityProfile(id: 5, name: "4K"),
            ]
        )
    }
}
