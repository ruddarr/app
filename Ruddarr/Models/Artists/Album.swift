//
//  Albums.swift
//  Ruddarr
//
//  Created by Tulus on 8/5/2026.
//
import SwiftUI
import CoreSpotlight

struct Album: Media, Identifiable, Equatable, Codable {
    let id: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let artistId: Int
    let foreignAlbumId: String?

    let title: String
    let disambiguation: String?
    let overview: String?

    var monitored: Bool
    let anyReleaseOk: Bool
    let profileId: Int

    let albumType: String?
    let secondaryTypes: [String]

    var releaseDate: Date?
    let releases: [AlbumRelease]
    let genres: [String]

    let duration: Int
    let mediumCount: Int
    let media: [AlbumMedium]
    let artist: Artist?

    let images: [MediaImage]
    let remoteCover: String?

    let links: [AlbumLink]
    let lastSearchTime: Date?

    let addOptions: AlbumAddOptions?

    let ratings: AlbumRatings?
    let statistics: AlbumStatistics?

    enum CodingKeys: String, CodingKey {
        case id
        case artistId
        case foreignAlbumId
        case title
        case disambiguation
        case overview
        case monitored
        case anyReleaseOk
        case profileId
        case albumType
        case secondaryTypes
        case releaseDate
        case releases
        case genres
        case duration
        case mediumCount
        case media
        case artist
        case remoteCover
        case images
        case links
        case lastSearchTime
        case addOptions
        case ratings
        case statistics
    }

    var remotePoster: String? {
        remoteCover
    }

    var trackCount: Int {
        statistics?.trackCount ?? 0
    }

    var trackFileCount: Int {
        statistics?.trackFileCount ?? 0
    }

    var percentOfTracks: Float {
        statistics?.percentOfTracks ?? 0
    }

    var sizeOnDisk: Int {
        statistics?.sizeOnDisk ?? 0
    }

    var progressLabel: String? {
        guard let stats = statistics else { return nil }
        return "\(stats.trackFileCount) / \(stats.totalTrackCount)"
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

extension Album {
    func searchableItem(poster: URL?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.mp3)
        attributes.artist = artist?.artistName
        attributes.genre = genres.first
        attributes.addedDate = releaseDate
        attributes.thumbnailURL = poster
        attributes.userCurated = NSNumber(value: monitored)
        attributes.userOwned = NSNumber(value: (statistics?.percentOfTracks ?? 0) > 0)

        attributes.contentDescription = [title, overview, artist?.artistName, String(localized: "\(mediumCount) Track")]
            .compactMap { $0 }
            .joined(separator: " · ")

        return CSSearchableItem(
            uniqueIdentifier: "albums:\(id):\(instanceId?.uuidString ?? "")",
            domainIdentifier: instanceId?.uuidString,
            attributeSet: attributes
        )
    }

    var searchableHash: String {
        "\(id):\(String(describing: title)):\(String(describing: artist?.artistName)):\(String(describing: releaseDate?.formatted(Date.FormatStyle().year())))"
    }
}

struct AlbumRelease: Identifiable, Equatable, Codable {
    let id: Int
    let albumId: Int
    let foreignReleaseId: String?

    let title: String?
    let status: String?

    let duration: Int
    let trackCount: Int

    let media: [AlbumMedium]
    let mediumCount: Int

    let disambiguation: String?
    let country: [String]
    let label: [String]
    let format: String?

    let monitored: Bool
}

struct AlbumLink: Equatable, Codable {
    let url: String?
    let name: String?
}

struct AlbumRatings: Equatable, Codable {
    let votes: Int
    let value: Float
}

struct AlbumStatistics: Equatable, Codable {
    let trackFileCount: Int
    let trackCount: Int
    let totalTrackCount: Int
    let sizeOnDisk: Int
    let percentOfTracks: Float
}

struct AlbumAddOptions: Equatable, Codable {
    let addType: ArtistMonitorType
    let searchForNewAlbum: Bool
}

struct AlbumMonitorResource: Equatable, Codable {
    let albumIds: [Int]
    let monitored: Bool
}

enum AlbumAddType: String, Codable {
    var id: Self { self }

    case automatic
    case manual

    var label: String {
        switch self {
        case .automatic: String(localized: "Automatic", comment: "Album add option")
        case .manual: String(localized: "Manual", comment: "Album add option")
        }
    }
}

struct AlbumMedium: Equatable, Codable {
    let mediumNumber: Int
    let mediumName: String?
    let mediumFormat: String?
}

extension Album {
    static var void: Self {
        .init(
            id: 0,
            instanceId: nil,
            artistId: 0,
            foreignAlbumId: nil,
            title: "",
            disambiguation: nil,
            overview: nil,
            monitored: false,
            anyReleaseOk: false,
            profileId: 0,
            albumType: nil,
            secondaryTypes: [],
            releaseDate: nil,
            releases: [],
            genres: [],
            duration: 0,
            mediumCount: 0,
            media: [],
            artist: nil,
            images: [],
            remoteCover: nil,
            links: [],
            lastSearchTime: nil,
            addOptions: nil,
            ratings: nil,
            statistics: nil
        )
    }
}
