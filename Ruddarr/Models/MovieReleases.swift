import os
import SwiftUI

@Observable
class MovieReleases {
    var instance: Instance

    var items: [MovieRelease] = []
    var error: Error?

    var isSearching: Bool = false

    var indexers: [String] = []
    var qualities: [String] = []
    var customFormats: [String] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ movie: Movie) async {
        items = []
        error = nil

        do {
            isSearching = true
            items = try await dependencies.api.lookupReleases(movie.movieId!, instance)
            setIndexers()
            setQualities()
            setCustomFormats()
        } catch is CancellationError {
            // do nothing
        } catch let urlError as URLError where urlError.code == .cancelled {
            // do nothing
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "movie.releases", message: "Movie releases lookup failed", data: ["error": error])
        }

        isSearching = false
    }

    func setIndexers() {
        var seen: Set<String> = []

        indexers = items
            .map { $0.indexerLabel }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    func setQualities() {
        var seen: Set<String> = []

        qualities = items
            .sorted { $0.quality.quality.resolution > $1.quality.quality.resolution }
            .map { $0.quality.quality.normalizedName }
            .filter { seen.insert($0).inserted }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .filter { $0.hasCustomFormats }
            .flatMap { $0.customFormats.unsafelyUnwrapped.map { $0.label } }

        customFormats = Array(Set(customFormatNames))
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
    let ageMinutes: Float
    let rejected: Bool

    let customFormats: [MovieReleaseCustomFormat]?
    let customFormatScore: Int

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
        case customFormats
        case customFormatScore
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

    var isFreeleech: Bool {
        guard !indexerFlags.isEmpty else { return false }

        return cleanIndexerFlags.contains { $0.lowercased().contains("freeleech") }
    }

    var isProper: Bool {
        quality.revision.isProper
    }

    var isRepack: Bool {
        quality.revision.isRepack
    }

    var hasCustomFormats: Bool {
        if let formats = customFormats {
            return !formats.isEmpty
        }

        return false
    }

    var hasNonFreeleechFlags: Bool {
        guard !indexerFlags.isEmpty else { return false }

        return !(indexerFlags.count == 1 && isFreeleech)
    }

    var cleanTitle: String {
        title.replacingOccurrences(of: ".", with: " ")
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
        guard !indexerFlags.isEmpty else {
            return nil
        }

        return cleanIndexerFlags.formatted(.list(type: .and, width: .narrow))
    }

    var languageLabel: String {
        if languages.isEmpty {
            return String(localized: "Unknown")
        }

        if languages.count == 1 {
            return languages[0].label

        }

        return String(localized: "Multilingual")
    }

    var languagesLabel: String? {
        if languages.isEmpty {
            return String(localized: "Unknown")
        }

        return languages.map { $0.label }
            .formatted(.list(type: .and, width: .narrow))
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
        let formatter = ByteCountFormatter()
        formatter.isAdaptive = size < 1_073_741_824 // 1 GB

        return formatter.string(fromByteCount: Int64(size))
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

        return String(localized: "Unknown")
    }

    var ageLabel: String {
        let minutes: Int = Int(ageMinutes)
        let days: Int = minutes / 60 / 24
        let years: Float = Float(days) / 30 / 12

        return switch minutes {
        case -10_000..<1: // less than 1 minute (or bad data from radarr)
            String(localized: "Just now")
        case 1..<119: // less than 120 minutes
            String(format: String(localized: "%d minutes"), minutes)
        case 120..<2_880: // less than 48 hours
            String(format: String(localized: "%d hours"), minutes / 60)
        case 2_880..<129_600: // less than 90 days
            String(format: String(localized: "%d days"), days)
        case 129_600..<525_600: // less than 365 days
            String(format: String(localized: "%d months"), days / 30)
        case 525_600..<2_628_000: // less than 5 years
            String(format: String(localized: "%.1f years"), years)
        default:
            String(format: String(localized: "%d years"), Int(years))
        }
    }

    var customFormatScoreLabel: String {
        String(
            format: "%@%d",
            customFormatScore < 0 ? "-" : "+",
            customFormatScore
        )
    }
}

struct MovieReleaseLanguage: Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieReleaseCustomFormat: Identifiable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieReleaseQuality: Codable {
    let quality: MovieReleaseQualityDetails
    let revision: MovieReleaseRevisionDetails
}

struct MovieReleaseQualityDetails: Codable {
    let name: String?
    let resolution: Int
    let source: String // unknown, cam, telesync, telecine, workprint, dvd, tv, webdl, webrip, bluray
    let modifier: String // none, regional, screener, rawhd, brdisk, remux

    var normalizedName: String {
        guard let label = name else {
            return String(localized: "Unknown")
        }

        if let range = label.range(of: #"-(\d+p)$"#, options: .regularExpression) {
            return String(name![range].dropFirst())
        }

        return label
            .replacingOccurrences(of: "BR-DISK", with: "1080p")
            .replacingOccurrences(of: "DVD-R", with: "480p")
            .replacingOccurrences(of: "SDTV", with: "480p")
    }
}

struct MovieReleaseRevisionDetails: Codable {
    let version: Int
    let real: Int
    let isRepack: Bool

    var isReal: Bool {
        real > 0
    }

    var isProper: Bool {
        version > 1
    }
}

struct DownloadMovieRelease: Codable {
    let guid: String
    let indexerId: Int
}
