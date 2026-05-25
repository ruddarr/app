import Foundation

struct AlbumTrackFile: Identifiable, Equatable, Codable {
    let id: Int
    let size: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let artistId: Artist.ID
    let albumId: Album.ID?
    let path: String?
    let dateAdded: Date?
    let sceneName: String?
    let releaseGroup: String?
    let quality: MediaQuality?
    let qualityWeight: Int

    let customFormats: [MediaQualityDetails]?
    let customFormatScore: Int?

    let indexerFlags: Int?
    let mediaInfo: TrackMediaInfo?
    let qualityCutoffNotMet: Bool
    let audioTags: TrackFileInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case size
        case artistId
        case albumId
        case path
        case dateAdded
        case sceneName
        case releaseGroup
        case quality
        case qualityWeight
        case customFormats
        case customFormatScore
        case indexerFlags
        case mediaInfo
        case qualityCutoffNotMet
        case audioTags
    }

    var filenameLabel: String {
        path?.components(separatedBy: "/").last?.breakable() ?? "--"
    }

    var sizeLabel: String {
        formatBytes(size)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore ?? 0)
    }

    var customFormatsList: [String]? {
        guard let formats = customFormats, !formats.isEmpty else {
            return nil
        }

        return formats.map { $0.label }
    }

    func bitrateLabel(_ runtime: Int) -> String? {
        guard runtime > 0 else { return nil }

        guard let bitrate = calculateBitrate(runtime * 60, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return String(format: "~%@", label)
    }
}

struct TrackFileInfo: Equatable, Codable {
    let title: String?
    let cleanTitle: String?
    let artistTitle: String?
    let albumTitle: String?
    let artistTitleInfo: TrackArtistTitleInfo?
    let artistMBId: String?
    let albumMBId: String?
    let releaseMBId: String?
    let recordingMBId: String?
    let trackMBId: String?

    let discNumber: Int?
    let discCount: Int?

    let country: TrackMediaCountry?

    let year: Int

    let label: String?
    let catalogNumber: String?

    let disambiguation: String?

    let duration: DateInterval?

    let quality: MediaQuality?
    let mediaInfo: TrackMediaInfo?
    let trackNumbers: [Int?]

    let releaseGroup: String?
    let releaseHash: String?
}

struct TrackMediaCountry: Equatable, Codable {
    let twoLetterCode: String?
    let name: String?
}

struct TrackArtistTitleInfo: Equatable, Codable {
    let title: String?
    let titleWithoutYear: String?
    let year: Int
}

struct TrackMediaInfo: Equatable, Codable {
    let audioCodec: String?
    let audioBitRate: String?
    let audioChannels: Int?
    let audioBits: String?
    let audioSampleRate: String?
}

extension AlbumTrackFile {
    static var void: Self {
        .init(
            id: 0,
            size: 0,
            instanceId: nil,
            artistId: 0,
            albumId: 0,
            path: nil,
            dateAdded: nil,
            sceneName: nil,
            releaseGroup: nil,
            quality: nil,
            qualityWeight: 0,
            customFormats: [],
            customFormatScore: 0,
            indexerFlags: nil,
            mediaInfo: nil,
            qualityCutoffNotMet: false,
            audioTags: nil
        )
    }
}
