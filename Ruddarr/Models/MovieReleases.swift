import os
import SwiftUI

@Observable
class MovieReleases {
    var instance: Instance

    var items: [MovieRelease] = []
    var error: Error?

    var isSearching: Bool = false

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

            leaveBreadcrumb(.error, category: "movie.releases", message: "Movie releases lookup failed", data: ["error": error])
        }

        isSearching = false
    }
}

struct MovieRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String
    let mappedMovieId: Int?
    let type: String
    let title: String
    let size: Int
    let age: Int
    let ageMinutes: Double
    let rejected: Bool

    let indexerId: Int
    let indexer: String?
    let indexerFlags: [String]
    let seeders: Int?
    let leechers: Int?

    let quality: MovieReleaseQuality
    let languages: [MovieReleaseLanguage]
    let rejections: [String]

    let qualityWeight: Int
    let releaseWeight: Int

    let infoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case mappedMovieId
        case type = "protocol"
        case title
        case size
        case age
        case ageMinutes
        case rejected
        case indexerId
        case indexer
        case indexerFlags
        case seeders
        case leechers
        case quality
        case languages
        case rejections
        case qualityWeight
        case releaseWeight
        case infoUrl
    }

    var isTorrent: Bool {
        type == "torrent"
    }

    var isUsenet: Bool {
        type == "usenet"
    }

    var cleanIndexerFlags: [String] {
        indexerFlags.map {
            $0.hasPrefix("G_") ? String($0.dropFirst(2)) : $0
        }
    }

    var indexerLabel: String {
        guard let indexer = indexer, indexer.hasSuffix(" (Prowlarr)") else {
            return indexer ?? String(indexerId)
        }

        return String(indexer.dropLast(11))
    }

    var indexerFlagsLabel: String? {
        indexerFlags.isEmpty ? nil : cleanIndexerFlags.joined(separator: ", ")
    }

    var languageLabel: String? {
        guard !languages.isEmpty else {
            return nil
        }

        return languages.map { $0.name ?? String($0.id) }.joined(separator: ", ")
    }

    var typeLabel: String {
        if isTorrent {
            return "Torrent (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        if isUsenet {
            return "Usenet"
        }

        return type
    }

    var sizeLabel: String {
        ByteCountFormatter().string(
            fromByteCount: Int64(size)
        )
    }

    var qualityLabel: String {
        let name = quality.quality.name
        let resolution = String(quality.quality.resolution)

        if let label = name {
            if label.contains(resolution) {
                return label
            }

            if quality.quality.resolution > 0 {
                return "\(label) (\(resolution)p)"
            }

            return label
        }

        if quality.quality.resolution > 0 {
            return "\(resolution)p"
        }

        return "Unknown"
    }

    var ageLabel: String {
        let days = ageMinutes / 60 / 24

        return switch ageMinutes {
        case -10_000..<1: "Just now" // less than 1 minute (or bad data from radarr)
        case 1..<119: String(format: "%.0f minutes", ageMinutes) // less than 120 minutes
        case 120..<2_880: String(format: "%.0f hours", ageMinutes / 60) // less than 48 hours
        case 2_880..<129_600: String(format: "%.0f days", days) // less than 90 days
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
    let name: String?
    let resolution: Int
}

struct DownloadMovieRelease: Codable {
    let guid: String
    let indexerId: Int
}
