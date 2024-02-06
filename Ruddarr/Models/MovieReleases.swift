import os
import SwiftUI

@Observable
class MovieReleases {
    var instance: Instance

    var items: [MovieRelease] = []
    var error: Error?

    var isSearching: Bool = false

    private let log: Logger = logger("models.movie.releases")

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ movie: Movie) async {
        items = []
        error = nil

        do {
            isSearching = true
            items = try await dependencies.api.lookupReleases(movie.movieId!, instance)
        } catch {
            self.error = error

            log.error("Failed to look up movie releases: \(error)")
        }

        isSearching = false
    }
}

struct MovieRelease: Identifiable, Codable {
    var id: String {
        guard guid != nil else {
            fatalError("Missing release guid")
        }

        return guid!
    }

    let guid: String?
    let mappedMovieId: Int?
    let type: String
    let title: String
    let size: Int
    let ageMinutes: Double
    let rejected: Bool

    let indexerId: Int
    let indexer: String?
    let indexerFlags: [String]
    let seeders: Int?
    let leechers: Int?

    let quality: MovieReleaseQuality

    let languages: [MovieReleaseLanguage]

    let qualityWeight: Int
    let releaseWeight: Int

    let infoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case mappedMovieId
        case type = "protocol"
        case title
        case size
        case ageMinutes
        case rejected
        case indexerId
        case indexer
        case indexerFlags
        case seeders
        case leechers
        case quality
        case languages
        case qualityWeight
        case releaseWeight
        case infoUrl
    }

    var indexerLabel: String {
        guard let indexer = indexer, indexer.hasSuffix(" (Prowlarr)") else {
            return indexer ?? String(indexerId)
        }

        return String(indexer.dropLast(11))
    }

    var flagsLabel: String? {
        indexerFlags.isEmpty ? nil : indexerFlags.joined(separator: ", ")
    }

    var languageLabel: String? {
        guard !languages.isEmpty else {
            return nil
        }

        return languages.map { $0.name ?? String($0.id) }.joined(separator: ", ")
    }

    var typeLabel: String {
        if type == "torrent" {
            return "Torrent (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        if type == "usenet" {
            return "Usenet"
        }

        return type
    }

    var sizeLabel: String {
        ByteCountFormatter().string(
            fromByteCount: Int64(size)
        )
    }

    var ageLabel: String {
        let days = ageMinutes / 60 / 24

        return switch ageMinutes {
        case 0..<1: "Just now" // less than 1 minute
        case 1..<119: String(format: "%.0f minutes", ageMinutes) // less than 120 minutes
        case 120..<2880: String(format: "%.0f hours", ageMinutes / 60) // less than 48 hours
        case 2880..<129_600: String(format: "%.0f days", days) // less than 90 days
        case 129_600..<525_600: String(format: "%.0f months", days / 30) // less than 365 days
        default: String(format: "%.1f years", days / 30 / 12)
        }
    }
}

struct MovieReleaseLanguage: Codable {
    let id: Int
    let name: String?
}

struct MovieReleaseQuality: Codable {
    let quality: MovieReleaseQualityDetails
}

struct MovieReleaseQualityDetails: Codable {
    let name: String
}
