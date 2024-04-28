import SwiftUI

// swiftlint:disable file_length
struct Movie: Identifiable, Codable {
    // movies only have an `id` after being added
    var id: Int { guid ?? (tmdbId + 100_000) }

    // the remapped `id` field
    var guid: Int?

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let tmdbId: Int
    let imdbId: String?

    let title: String
    let sortTitle: String
    let studio: String?
    let year: Int
    var sortYear: Int { year == 0 ? 2100 : year }
    let runtime: Int
    let overview: String?
    let certification: String?
    let youTubeTrailerId: String?
    let alternateTitles: [AlternateMovieTitle]

    let genres: [String]
    let ratings: MovieRatings?
    let popularity: Float?

    let status: MovieStatus
    var minimumAvailability: MovieStatus

    var monitored: Bool
    var qualityProfileId: Int
    let sizeOnDisk: Int?
    let hasFile: Bool?
    let isAvailable: Bool

    var path: String?
    var relativePath: String?
    var folderName: String?
    var rootFolderPath: String?

    let added: Date
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?

    let images: [MovieImage]
    let movieFile: MovieFile?

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tmdbId
        case imdbId
        case title
        case sortTitle
        case alternateTitles
        case studio
        case year
        case runtime
        case overview
        case certification
        case youTubeTrailerId
        case genres
        case ratings
        case popularity
        case status
        case minimumAvailability
        case monitored
        case qualityProfileId
        case sizeOnDisk
        case hasFile
        case isAvailable
        case path
        case folderName
        case rootFolderPath
        case added
        case inCinemas
        case physicalRelease
        case digitalRelease
        case images
        case movieFile
    }

    var exists: Bool {
        guid != nil
    }

    var stateLabel: LocalizedStringKey {
        if isDownloaded {
            return "Downloaded"
        }

        if isWaiting {
            return "Waiting"
        }

        if monitored && isAvailable {
            return "Missing"
        }

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

    func releaseType(for date: Date) -> LocalizedStringKey? {
        let calendar: Calendar = Calendar.current

        if let inCinemas = inCinemas, calendar.isDate(date, inSameDayAs: inCinemas) {
            return "In Cinemas" // popcorn
        }

        if let digital = digitalRelease, calendar.isDate(date, inSameDayAs: digital) {
            return "Digital Release" // arrow.down.doc
        }

        if let physical = physicalRelease, calendar.isDate(date, inSameDayAs: physical) {
            return "Physical Release" // opticaldisc
        }

        return nil
    }

    var sizeLabel: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(sizeOnDisk ?? 0),
            countStyle: .binary
        )
    }

    var genreLabel: String {
        genres.formatted(.list(type: .and, width: .narrow))
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var remoteFanart: String? {
        if let remote = self.images.first(where: { $0.coverType == "fanart" }) {
            return remote.remoteURL
        }

        return nil
    }

    var isDownloaded: Bool {
        hasFile ?? false
    }

    var isWaiting: Bool {
        switch status {
        case .tba, .announced:
            true // status == .announced && digitalRelease <= today
        case .inCinemas:
            minimumAvailability == .released
        case .released, .deleted:
            false
        }
    }

    func alternateTitlesString() -> String {
        alternateTitles.map { $0.title }.joined(separator: " ")
    }

    struct MovieRatings: Codable {
        let imdb: MovieRating?
        let tmdb: MovieRating?
        let metacritic: MovieRating?
        let rottenTomatoes: MovieRating?
    }
}

enum MovieStatus: String, Codable {
    case tba
    case announced
    case inCinemas
    case released
    case deleted

    var label: String {
        switch self {
        case .tba: String(localized: "TBA")
        case .announced: String(localized: "Announced")
        case .inCinemas: String(localized: "In Cinemas")
        case .released: String(localized: "Released")
        case .deleted: String(localized: "Deleted")
        }
    }
}

struct AlternateMovieTitle: Codable {
    let title: String
}

struct MovieImage: Codable {
    let coverType: String
    let remoteURL: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
        case url
    }
}

struct MovieRating: Codable {
    let votes: Int
    let value: Float
}

struct MovieFile: Identifiable, Codable {
    let id: Int
    let size: Int
    let relativePath: String?
    let dateAdded: Date

    let mediaInfo: MovieMediaInfo?
    let quality: MovieQualityInfo
    let languages: [MovieLanguage]
    let customFormats: [MovieCustomFormat]?
    let customFormatScore: Int?

    var sizeLabel: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(size),
            countStyle: .binary
        )
    }

    var languageLabel: String {
        languageSingleLabel(languages)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore ?? 0)
    }

    var customFormatsList: [String]? {
        guard let formats = customFormats else {
            return nil
        }

        return formats.map { $0.label }
    }

    var videoResolution: Int? {
        if quality.quality.resolution > 0 {
            return quality.quality.resolution
        }

        if let resolution = mediaInfo?.resolution, let range = resolution.range(of: "x") {
            return Int(resolution[range.upperBound...])
        }

        return nil
    }
}

struct MovieMediaInfo: Codable {
    let audioBitrate: Int
    let audioStreamCount: Int
    let audioChannels: Float
    let audioCodec: String?
    let audioLanguages: String?

    let videoBitDepth: Int
    let videoBitrate: Int
    let videoFps: Float
    let videoCodec: String?
    let resolution: String?
    let runTime: String?
    let videoDynamicRange: String?
    let videoDynamicRangeType: String?
    let scanType: String?

    let subtitles: String?

    var videoCodecLabel: String? {
        guard var label = videoCodec else {
            return nil
        }

        label = label.replacingOccurrences(of: "x264", with: "H264")
        label = label.replacingOccurrences(of: "h264", with: "H264")
        label = label.replacingOccurrences(of: "h265", with: "HEVC")
        label = label.replacingOccurrences(of: "x265", with: "HEVC")

        return label
    }

    var videoDynamicRangeLabel: String? {
        guard let label = videoDynamicRange, !label.isEmpty else {
            return nil
        }

        if let type = videoDynamicRangeType {
            if type == "HDR10" { return "HDR10" }
            if type == "HDR10Plus" { return "HDR10+" }
            if !type.isEmpty { return "\(label) (\(type))" }
        }

        return label
    }

    var audioLanguageCodes: [String]? {
        guard let languages = audioLanguages, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }

    var subtitleCodes: [String]? {
        guard let languages = subtitles, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }
}

struct MovieQualityInfo: Codable {
    let quality: MovieQuality
}

struct MovieQuality: Codable {
    let name: String?
    let resolution: Int

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieLanguage: Codable {
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieCustomFormat: Identifiable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieEditorResource: Codable {
    let movieIds: [Int]
    let monitored: Bool?
    let qualityProfileId: Int?
    let minimumAvailability: MovieStatus?
    let rootFolderPath: String?
    let moveFiles: Bool?
}

func formatCustomScore(_ score: Int) -> String {
    String(format: "%@%d", score < 0 ? "-" : "+", score)
}

func languageSingleLabel(_ languages: [MovieLanguage]) -> String {
    if languages.isEmpty {
        return String(localized: "Unknown")
    }

    if languages.count == 1 {
        return languages[0].label

    }

    return String(localized: "Multilingual")
}

func languagesList(_ codes: [String]) -> String {
    codes.map {
        $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
    }.formatted(.list(type: .and, width: .narrow))
}

// swiftlint:enable file_length
