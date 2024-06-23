import SwiftUI

struct Movie: Identifiable, Equatable, Codable {
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
    let runtime: Int
    let overview: String?
    let certification: String?
    let youTubeTrailerId: String?
    let originalLanguage: MediaLanguage?
    let alternateTitles: [MediaAlternateTitle]

    let genres: [String]
    let ratings: MovieRatings?
    let popularity: Float?

    let status: MovieStatus
    var minimumAvailability: MovieStatus

    var monitored: Bool
    var qualityProfileId: Int
    let sizeOnDisk: Int?
    let hasFile: Bool?

    var path: String?
    var relativePath: String?
    var folderName: String?
    var rootFolderPath: String?

    let added: Date
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?

    let images: [MediaImage]
    let movieFile: MediaFile?

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
        case originalLanguage
        case genres
        case ratings
        case popularity
        case status
        case minimumAvailability
        case monitored
        case qualityProfileId
        case sizeOnDisk
        case hasFile
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

    var sizeLabel: String {
        guard let bytes = sizeOnDisk, bytes > 0 else { return "" }
        return formatBytes(bytes)
    }
    
    var sortYear: TimeInterval {
        if let date = inCinemas { return date.timeIntervalSince1970 }
        if let date = digitalRelease { return date.timeIntervalSince1970 }
        if year <= 0 { return Date.distantFuture.timeIntervalSince1970 }
        return DateComponents(calendar: .current, year: year).date?.timeIntervalSince1970
            ?? Date.distantFuture.timeIntervalSince1970
    }

    var stateLabel: LocalizedStringKey {
        if isDownloaded {
            return "Downloaded"
        }

        if isWaiting {
            if status == .tba || status == .announced {
                return "Unreleased"
            }

            return "Waiting"
        }

        if monitored {
            return "Missing"
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

    var certificationLabel: String {
        guard let rating = certification else {
            return String(localized: "Unrated")
        }

        if rating.isEmpty || rating == "0" {
            return String(localized: "Unrated")
        }

        return rating
    }

    var ratingsExist: Bool {
        ratings?.rottenTomatoes?.value != nil ||
        ratings?.imdb?.value != nil ||
        (ratings?.tmdb?.value ?? 0) > 0 ||
        ratings?.metacritic?.value != nil
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

    var genreLabel: String {
        genres.prefix(3)
            .map { $0.replacingOccurrences(of: "Science Fiction", with: "Sci-Fi") }
            .formattedList()
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var isDownloaded: Bool {
        hasFile ?? false
    }

    var isReleased: Bool {
        status == .released
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

    struct MovieRatings: Equatable, Codable {
        let imdb: MovieRating?
        let tmdb: MovieRating?
        let metacritic: MovieRating?
        let rottenTomatoes: MovieRating?
    }
}

enum MovieStatus: String, Equatable, Codable {
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

struct MovieRating: Equatable, Codable {
    let votes: Int
    let value: Float
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
