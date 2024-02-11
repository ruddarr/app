import SwiftUI

struct Movie: Identifiable, Codable {
    var id: Int { movieId ?? tmdbId }

    var movieId: Int?
    let tmdbId: Int

    let title: String
    let sortTitle: String
    let studio: String?
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?

    let genres: [String]
    let ratings: MovieRatings?

    let status: MovieStatus
    var minimumAvailability: MovieStatus

    var monitored: Bool
    var qualityProfileId: Int
    let sizeOnDisk: Int?
    let hasFile: Bool
    let isAvailable: Bool

    var path: String?
    var folderName: String?
    var rootFolderPath: String?

    let added: Date
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?

    let images: [MovieImage]
    let movieFile: MovieFile?

    enum CodingKeys: String, CodingKey {
        case movieId = "id"
        case tmdbId
        case title
        case sortTitle
        case studio
        case year
        case runtime
        case overview
        case certification
        case genres
        case ratings
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
        movieId != nil
    }

    var stateLabel: String? {
        if hasFile {
            return "Downloaded"
        }

        if isWaiting {
            return "Waiting"
        }

        if monitored && isAvailable {
            return "Missing"
        }

        return nil
    }

    var runtimeLabel: String {
        let hours = runtime / 60
        let minutes = runtime % 60

        return hours == 0 ? "\(minutes)m" : "\(hours)h \(minutes)m"
    }

    var sizeLabel: String {
        ByteCountFormatter().string(
            fromByteCount: Int64(sizeOnDisk ?? 0)
        )
    }

    var genreLabel: String {
        genres.joined(separator: ", ")
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

    var isWaiting: Bool {
        switch status {
        case .tba, .announced:
            true // status == .announced && digitalRelease <= today
        case .inCinemas:
            minimumAvailability != .released
        case .released, .deleted:
            false
        }
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
        case .tba: "TBA"
        case .announced: "Announced"
        case .inCinemas: "In Cinemas"
        case .released: "Released"
        case .deleted: "Deleted"
        }
    }
}

struct MovieImage: Codable {
    let coverType: String
    let remoteURL: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
        case url
    }
}

struct MovieRatings: Codable {
    let imdb: MovieRating?
    let tmdb: MovieRating?
    let metacritic: MovieRating?
    let rottenTomatoes: MovieRating?
}

struct MovieRating: Codable {
    let votes: Int
    let value: Double
}

struct MovieFile: Codable {
    let mediaInfo: MovieMediaInfo
    let quality: MovieQualityInfo
    let languages: [MovieLanguages]
}

struct MovieMediaInfo: Codable {
    let audioCodec: String?
    let videoCodec: String?
    let resolution: String?
}

struct MovieQualityInfo: Codable {
    let quality: MovieQuality
}

struct MovieQuality: Codable {
    let name: String?
    let resolution: Int
}

struct MovieLanguages: Codable {
    let name: String?
}

struct MovieEditorResource: Codable {
    let movieIds: [Int]
    let monitored: Bool?
    let qualityProfileId: Int?
    let minimumAvailability: MovieStatus?
    let rootFolderPath: String?
    let moveFiles: Bool?
}
