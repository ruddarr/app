import os
import SwiftUI

@MainActor
@Observable
class ArtistReleases {
    var instance: Instance

    var items: [ArtistRelease] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    var indexers: [String] = []
    var qualities: [String] = []
    var protocols: [String] = []
    var languages: [String] = []
    var customFormats: [String] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ artist: Artist, _ album: Album.ID?) async {
        items = []
        error = nil
        isSearching = true
        setFilterData()

        do {
            items = try await dependencies.api.lookupArtistReleases(artist.id, album, instance)
            setFilterData()
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.releases", message: "Artist releases lookup failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSearching = false
    }

    func setFilterData() {
        setIndexers()
        setQualities()
        setProtocols()
        setCustomFormats()
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
            .map { $0.quality.quality.normalizedName }
            .filter { seen.insert($0).inserted }
    }

    func setProtocols() {
        var seen: Set<String> = []

        protocols = items
            .map { $0.network.label }
            .filter { seen.insert($0).inserted }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .filter { $0.hasCustomFormats }
            .flatMap { $0.customFormats.unsafelyUnwrapped.map { $0.label } }

        customFormats = Array(Set(customFormatNames))
    }
}

struct ArtistRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String
    let title: String
    let artistId: Int?
    let artistName: String?
    let albumId: Int?
    let albumName: String?
    let size: Int
    let age: Int
    let ageHours: Float
    let ageMinutes: Float
    let airDate: String?
    let publishedDate: Date?
    let approved: Bool
    let rejected: Bool
    let temporarilyRejected: Bool
    let downloadAllowed: Bool

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int

    let network: ReleaseProtocol
    let indexerId: Int
    let indexer: String?
    let indexerFlags: [String]?
    let seeders: Int?
    let leechers: Int?

    let discography: Bool
    let sceneSource: Bool

    let releaseGroup: String?
    let subGroup: String?

    let quality: AudioMediaQuality
    let rejections: [String]

    let qualityWeight: Int
    let releaseWeight: Int

    let magnetUrl: String?
    let downloadUrl: String?
    let commentsUrl: String?
    let infoUrl: String?
    let infoHash: String?
    let releaseHash: String?

    let downloadClientId: Int?
    let downloadClient: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case title
        case artistId
        case artistName
        case albumId
        case albumName
        case size
        case age
        case ageHours
        case ageMinutes
        case airDate
        case publishedDate
        case approved
        case rejected
        case temporarilyRejected
        case downloadAllowed
        case customFormats
        case customFormatScore
        case network = "protocol"
        case indexerId
        case indexer
        case indexerFlags
        case seeders
        case leechers
        case discography
        case sceneSource
        case releaseGroup
        case subGroup
        case quality
        case rejections
        case qualityWeight
        case releaseWeight
        case magnetUrl
        case downloadUrl
        case commentsUrl
        case infoUrl
        case infoHash
        case releaseHash
        case downloadClientId
        case downloadClient
    }

    var isTorrent: Bool {
        network == .torrent
    }

    var isUsenet: Bool {
        network == .usenet
    }

    var isFreeleech: Bool {
        guard !(indexerFlags ?? []).isEmpty else { return false }

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
        guard let flags = indexerFlags else { return false }
        guard !flags.isEmpty else { return false }

        return !(flags.count == 1 && isFreeleech)
    }

    var cleanIndexerFlags: [String] {
        guard let flags = indexerFlags else { return [] }

        return flags.map {
            guard let range = $0.range(of: "_") else { return $0 }
            return String($0[range.upperBound...])
        }
    }

    var indexerLabel: String {
        guard let name = indexer else {
            return String(indexerId)
        }

        return formatIndexer(name)
    }

    var indexerFlagsLabel: String? {
        guard !(indexerFlags ?? []).isEmpty else { return nil }

        return cleanIndexerFlags.formattedList()
    }

    var typeLabel: String {
        if network == .torrent {
            return "\(network.label) (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        return network.label
    }

    var sizeLabel: String {
        formatBytes(size)
    }

    var qualityLabel: String {
        let name = quality.quality.name
        let resolution = String(quality.quality.normalizedName)

        if let label = name {
            if label.contains(resolution) {
                return label
            }

            return label
        }

        return String(localized: "Unknown")
    }

    var ageLabel: String {
        formatAge(ageMinutes)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore)
    }

    func bitrateLabel(_ runtime: Int) -> String? {
        guard runtime > 0 else { return nil }

        guard let bitrate = calculateBitrate(runtime * 60, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return String(format: "~%@", label)
    }
}
