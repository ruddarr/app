import SwiftUI
import CoreSpotlight

struct Artist: Media, Identifiable, Equatable, Codable {
    // artists only have an `id` after being added
    var id: Int { guid ?? abs((foreignArtistId ?? UUID().uuidString).hashValue) }

    // the remapped `id` field
    var guid: Int?

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let tadbId: Int?
    let mbId: String?
    let foreignArtistId: String?
    let discogsId: Int?
    let allMusicId: Int?

    var title: String { artistName }
    let artistName: String
    let sortName: String?
    let cleanName: String?
    let artistType: String?

    let status: ArtistStatus

    let ended: Bool
    let overview: String?
    let disambiguation: String?

//    let nextAlbum: Album?
//    let lastAlbum: Album?

    var remotePoster: String? {
        (images.first { $0.coverType == "poster" } ?? images.first)?.remoteURL
    }
    let images: [MediaImage]
    let members: [ArtistMember]?
    let links: [ArtistLink]

    let path: String?
    let folder: String?
    var rootFolderPath: String?
    var qualityProfileId: Int?
    var metadataProfileId: Int?

    var monitored: Bool
    var monitorNewItems: ArtistMonitorNewItems?

    let genres: [String]
    var tags: [Int]

    let added: Date
    var addOptions: ArtistAddOptions?

    let ratings: ArtistRatings?
    var statistics: ArtistStatistics?

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tadbId
        case mbId
        case foreignArtistId
        case discogsId
        case allMusicId
        case artistName
        case sortName
        case cleanName
        case status
        case ended
        case overview
        case artistType
        case disambiguation
        case links
//        case nextAlbum
//        case lastAlbum
        case images
        case members
        case path
        case qualityProfileId
        case metadataProfileId
        case monitored
        case monitorNewItems
        case rootFolderPath
        case folder
        case genres
        case tags
        case added
        case addOptions
        case ratings
        case statistics
    }

    var exists: Bool {
        guid ?? 0 > 0
    }

    var albumCount: Int {
        statistics?.albumCount ?? 0
    }

    var trackCount: Int {
        statistics?.trackCount ?? 0
    }

    var trackFileCount: Int {
        statistics?.trackFileCount ?? 0
    }

    var sizeOnDisk: Int {
        statistics?.sizeOnDisk ?? 0
    }

    var percentOfTracks: Float {
        statistics?.percentOfTracks ?? 0
    }

    var genreLabel: String {
        genres.prefix(3)
            .map { $0 }
            .formattedList()
    }

    var stateLabel: LocalizedStringKey {
        if monitored && percentOfTracks < 100 {
            return trackFileCount == 0 ? "Missing" : "Missing Releases"
        }

        if monitored && percentOfTracks == 100 {
            return "Up to Date"
        }

        return "Unwanted"
    }

    var ratingScore: Float {
        guard let votes = ratings?.votes, votes > 0 else { return 0 }
        guard let rating = ratings?.value else { return 0 }

        return rating * log(Float(votes) + 1)
    }

    var sizeLabel: String? {
        guard let bytes = statistics?.sizeOnDisk, bytes > 0 else { return nil }
        return formatBytes(bytes)
    }
}

extension Artist {
    func searchableItem(poster: URL?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.mp3)
        attributes.artist = artistName
        attributes.genre = genres.first
        attributes.addedDate = added
        attributes.thumbnailURL = poster
        attributes.userCurated = NSNumber(value: monitored)
        attributes.userOwned = NSNumber(value: (statistics?.percentOfTracks ?? 0) > 0)

        attributes.contentDescription = [String(localized: "\(albumCount) Album"), String(localized: "\(trackCount) Track")]
            .compactMap { $0 }
            .joined(separator: " · ")

        return CSSearchableItem(
            uniqueIdentifier: "artists:\(id):\(instanceId?.uuidString ?? "")",
            domainIdentifier: instanceId?.uuidString,
            attributeSet: attributes
        )
    }

    var searchableHash: String {
        "\(id):\(artistName)"
    }
}

enum ArtistStatus: String, Equatable, Codable {
    case continuing
    case ended
    case deleted

    var label: String {
        switch self {
        case .continuing: String(localized: "Continuing", comment: "(Single word) Artists status")
        case .ended: String(localized: "Ended", comment: "(Single word) Artists status")
        case .deleted: String(localized: "Deleted", comment: "(Single word) Artists status")
        }
    }

    var icon: Image {
        switch self {
        case .continuing: Image(systemName: "play.fill")
        case .ended: Image(systemName: "stop.fill")
        case .deleted: Image(systemName: "xmark.circle")
        }
    }
}

struct ArtistLink: Equatable, Codable, Hashable, Identifiable {
    var id: UUID { UUID() }

    let url: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case url
        case name
    }
}

struct ArtistMember: Equatable, Codable {
    let name: String?
    let instrument: String?
    let images: [MediaImage]
}

struct ArtistRatings: Equatable, Codable {
    let votes: Int
    let value: Float
}

struct ArtistStatistics: Equatable, Codable {
    let sizeOnDisk: Int
    let albumCount: Int
    let trackCount: Int
    let trackFileCount: Int
    let totalTrackCount: Int
    let percentOfTracks: Float
}

struct ArtistAddOptions: Equatable, Codable {
    var monitor: ArtistMonitorType
//    let albumsToMonitor: [String]?
//    let monitored: Bool?
//    let searchForMissingAlbums: Bool?
}

enum ArtistMonitorNewItems: String, Codable, Identifiable, CaseIterable {
    var id: Self { self }

    case all
    case new
    case none

    var label: String {
        switch self {
        case .all: String(localized: "All Albums", comment: "Artists monitoring option")
        case .new: String(localized: "New Albums", comment: "Artists monitoring option")
        case .none: String(localized: "No Albums", comment: "Artists monitoring option")
        }
    }
}

enum ArtistMonitorType: String, Codable, Identifiable, CaseIterable {
    var id: Self { self }

    case unknown
    case all
    case future
    case missing
    case existing
    case latest
    case first
    case none

    var label: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .all: String(localized: "All Releases", comment: "Artists monitoring option")
        case .future: String(localized: "Future Releases", comment: "Artists monitoring option")
        case .missing: String(localized: "Missing Releases", comment: "Artists monitoring option")
        case .existing: String(localized: "Existing Releases", comment: "Artists monitoring option")
        case .first: String(localized: "First Release", comment: "Artists monitoring option")
        case .latest: ""
        case .none: String(localized: "None", comment: "Artists monitoring option")
        }
    }
}

struct ArtistUpdateResource: Codable {
    let id: Artist.ID
    let monitored: Bool?
    let monitorNewItems: ArtistMonitorNewItems
    let qualityProfileId: Int?
    let metadataProfileId: Int?
    let path: String?
    let rootFolderPath: String?
}

struct ArtistEditorResource: Codable {
    let artistsIds: [Int]
    let monitored: Bool?
    let monitorNewItems: ArtistMonitorNewItems
    let qualityProfileId: Int?
    let metadataProfileId: Int?
    let rootFolderPath: String?
    let tags: [Int]
    let applyTags: String
    let moveFiles: Bool?
}

struct ArtistDeleteResource: Codable {
    let trackFileIds: [Int]
}

extension Artist {
    static var void: Self {
        .init(
            guid: nil,
            instanceId: nil,
            tadbId: 0,
            mbId: nil,
            foreignArtistId: nil,
            discogsId: nil,
            allMusicId: nil,
            artistName: "",
            sortName: "",
            cleanName: nil,
            artistType: nil,
            status: .continuing,
            ended: false,
            overview: nil,
            disambiguation: nil,
//            nextAlbum: nil,
//            lastAlbum: nil,
//            remotePoster: nil,
            images: [],
            members: [],
            links: [],
            path: nil,
            folder: nil,
            rootFolderPath: nil,
            qualityProfileId: 0,
            metadataProfileId: 0,
            monitored: false,
            monitorNewItems: .all,
            genres: [],
            tags: [],
            added: .now,
            addOptions: nil,
            ratings: nil,
            statistics: nil
        )
    }
}
