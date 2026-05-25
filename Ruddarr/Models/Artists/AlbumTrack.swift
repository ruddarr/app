import SwiftUI

struct AlbumTrack: Identifiable, Codable, Equatable {
    let id: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let artistId: Int
    let foreignTrackId: String?
    let trackFileId: Int
    let albumId: Int

    let explicit: Bool

    let absoluteTrackNumber: Int
    let trackNumber: String?
    let title: String?
    let duration: Int
    let trackFile: AlbumTrackFile?

    let mediumNumber: Int
    let hasFile: Bool
    let artist: Artist?

    let ratings: AlbumTrackRatings?

    var runtime: Int {
        duration / 60_000
    }

    var numberLabel: String {
        trackNumber ?? "\(String(absoluteTrackNumber))"
    }

    var titleLabel: String {
        title ?? String(localized: "Unannounced", comment: "Missing media title")
    }

    var statusLabel: String {
        if hasFile {
            return String(localized: "Downloaded", comment: "(Single word) Track status label")
        }

        return String(localized: "Missing", comment: "(Single word) Track status label")
    }
}

struct AlbumTrackRatings: Codable, Equatable {
    let votes: Int
    let value: Double
}

extension AlbumTrack {
    static var void: Self {
        .init(
            id: 0,
            instanceId: nil,
            artistId: 0,
            foreignTrackId: nil,
            trackFileId: 0,
            albumId: 0,
            explicit: false,
            absoluteTrackNumber: 1,
            trackNumber: "1",
            title: nil,
            duration: 0,
            trackFile: nil,
            mediumNumber: 0,
            hasFile: false,
            artist: nil,
            ratings: nil
        )
    }
}
