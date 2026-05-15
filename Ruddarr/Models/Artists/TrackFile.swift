import Foundation

struct TrackFile: Identifiable, Equatable, Codable {
    let id: Int
    let size: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let artistId: Artist.ID
    let albumId: Album.ID?
    let path: String?
    let dateAdded: Date
    let sceneName: String?
    let releaseGroup: String?
    let quality: AudioMediaQuality?
    let qualityWeight: Int

    let customFormats: [AudioMediaQualityDetails]
    let customFormatScore: Int

    let indexerFlags: Int?
    let mediaInfo: FileMediaInfo?
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

    let quality: AudioMediaQuality?
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
    let audioFormat: String?
    let audioBitrate: Int
    let audioChannels: Int
    let audioBits: Int
    let audioSampleRate: Int
}
