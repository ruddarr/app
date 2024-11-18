import os
import SwiftUI

@Observable
class SeriesReleases {
    var instance: Instance

    var items: [SeriesRelease] = []

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

    @MainActor
    func search(_ series: Series, _ season: Season.ID?, _ episode: Episode.ID?) async {
        items = []
        error = nil
        isSearching = true
        setFilterData()

        do {
            items = try await dependencies.api.lookupSeriesReleases(series.id, season, episode, instance)
            setFilterData()
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.releases", message: "Series releases lookup failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSearching = false
    }

    func setFilterData() {
        setIndexers()
        setQualities()
        setProtocols()
        setLanguages()
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
            .sorted { $0.quality.quality.resolution > $1.quality.quality.resolution }
            .map { $0.quality.quality.normalizedName }
            .filter { seen.insert($0).inserted }
    }

    func setProtocols() {
        var seen: Set<String> = []

        protocols = items
            .map { $0.type.label }
            .filter { seen.insert($0).inserted }
    }

    func setLanguages() {
        var seen: Set<String> = []

        languages = items
            .map { $0.languages?.map { $0.label } ?? [] }
            .flatMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .filter { $0.hasCustomFormats }
            .flatMap { $0.customFormats.unsafelyUnwrapped.map { $0.label } }

        customFormats = Array(Set(customFormatNames))
    }
}

struct SeriesRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String

    let type: MediaReleaseType
    let title: String
    let seriesTitle: String?
    let size: Int
    let age: Int
    let ageMinutes: Float
    let rejected: Bool
    let downloadAllowed: Bool

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    let indexerId: Int
    let indexer: String?
    let indexerFlags: Int?
    let seeders: Int?
    let leechers: Int?

    let quality: MediaQuality
    let languages: [MediaLanguage]?
    let rejections: [String]

    let qualityWeight: Int
    let releaseWeight: Int

    let infoUrl: String?

    let fullSeason: Bool
    let episodeRequested: Bool
    let shouldOverride: Bool?
    let special: Bool
    let isPossibleSpecialEpisode: Bool

    let seriesId: Series.ID?
    let mappedSeriesId: Series.ID?

    let episodeId: Series.ID?
    let episodeIds: [Series.ID]?

    let seasonNumber: Season.ID
    let mappedSeasonNumber: Season.ID?

    let episodeNumbers: [Episode.ID]?
    let mappedEpisodeNumbers: [Episode.ID]?

    let mappedEpisodeInfo: [SeriesReleaseEpisode]?

    enum CodingKeys: String, CodingKey {
        case guid
        case type = "protocol"
        case title
        case seriesTitle
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
        case downloadAllowed
        case fullSeason
        case episodeRequested
        case shouldOverride
        case special
        case isPossibleSpecialEpisode
        case seriesId
        case mappedSeriesId
        case episodeId
        case episodeIds
        case seasonNumber
        case mappedSeasonNumber
        case episodeNumbers
        case mappedEpisodeNumbers
        case mappedEpisodeInfo
    }

    var isTorrent: Bool {
        type == .torrent
    }

    var isUsenet: Bool {
        type == .usenet
    }

    var isFreeleech: Bool {
        releaseFlags.contains(.freeleech)
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
        releaseFlags.contains { $0 != .freeleech }
    }

    var releaseFlags: [SeriesReleaseFlag] {
        guard let flags = indexerFlags, flags > 1 else {
            return []
        }

        return SeriesReleaseFlags.parse(flags)
    }

    var indexerLabel: String {
        guard let name = indexer else {
            return String(indexerId)
        }

        return formatIndexer(name)
    }

    var languageLabel: String {
        languageSingleLabel(languages ?? [])
    }

    var languagesLabel: String {
        guard let langs = languages, !langs.isEmpty else {
            return String(localized: "Unknown")
        }

        return langs.map { $0.label }.formattedList()
    }

    var typeLabel: String {
        if type == .torrent {
            return "\(type.label) (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        return type.label
    }

    var sizeLabel: String {
        formatBytes(size)
    }

    var qualityLabel: String {
        let name = quality.quality.name
        let resolution = String(quality.quality.resolution)

        if let label = name {
            if label.contains(resolution) {
                return label
            }

            if quality.quality.resolution > 0 {
                return "\(label)-\(resolution)p"
            }

            return label
        }

        if quality.quality.resolution > 0 {
            return "\(resolution)p"
        }

        return String(localized: "Unknown")
    }

    var ageLabel: String {
        formatAge(ageMinutes)
    }

    var scoreLabel: String? {
        guard let score = customFormatScore else { return nil }
        return formatCustomScore(score)
    }

    func bitrateLabel(_ runtime: Int) -> String? {
        guard runtime > 0 else { return nil }

        guard let bitrate = calculateBitrate(runtime * 60, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return String(format: "~%@", label)
    }
}

struct SeriesReleaseEpisode: Codable {
    let id: Episode.ID
    let seasonNumber: Season.ID
    let episodeNumber: Episode.ID
    let title: String?
}

struct SeriesReleaseFlags {
    static let map: [Int: SeriesReleaseFlag] = [
        1: .freeleech,
        2: .halfleech,
        4: .doubleUpload,
        8: .internal,
        16: .scene,
        32: .freeleech75,
        64: .freeleech25,
        128: .nuked,
    ]

    static func parse(_ value: Int) -> [SeriesReleaseFlag] {
        map.keys.filter { value & $0 != 0 }.compactMap { map[$0] }
    }
}

enum SeriesReleaseFlag {
    case freeleech
    case halfleech
    case doubleUpload
    case `internal`
    case scene
    case freeleech75
    case freeleech25
    case nuked

    var label: String {
        switch self {
        case .freeleech: "Freeleech"
        case .halfleech: "Halfleech"
        case .doubleUpload: "DoubleUpload"
        case .internal: "Internal"
        case .scene: "Scene"
        case .freeleech75: "Freeleech75"
        case .freeleech25: "Freeleech25"
        case .nuked: "Nuked"
        }
    }
}
