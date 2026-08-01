import os
import SwiftUI
import Sentry

@MainActor
@Observable
class MovieReleases {
    var instance: Instance

    var items: [MovieRelease] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    var indexers: [String] = []
    var qualities: [String] = []
    var protocols: [String] = []
    var languages: [String] = []
    var customFormats: [String] = []
    var releaseGroups: [String] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ movie: Movie) async {
        items = []
        error = nil
        isSearching = true
        setFilterData()

        do {
            items = try await dependencies.api.lookupMovieReleases(movie.id, instance)
            setFilterData()
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "movie.releases", message: "Movie releases lookup failed", data: ["error": apiError])
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
        setReleaseGroups()
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
            .map { $0.network.label }
            .filter { seen.insert($0).inserted }
    }

    func setLanguages() {
        var seen: Set<String> = []

        languages = items
            .map { $0.languages.map(\.label) }
            .flatMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func setReleaseGroups() {
        var seen: Set<String> = []

        releaseGroups = items
            .compactMap { $0.releaseGroupLabel }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .compactMap { $0.customFormats }
            .flatMap { $0 }
            .map { $0.label }

        customFormats = Array(Set(customFormatNames))
    }
}

struct MovieRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String
    let title: String
    let size: Int
    let age: Int
    let ageMinutes: Float
    let rejected: Bool
    let downloadAllowed: Bool
    let releaseGroup: String?

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int

    let network: ReleaseProtocol
    let indexerId: Int
    let indexer: String?
    let indexerFlags: [String]?
    let seeders: Int?
    let leechers: Int?

    let quality: MediaQuality
    let languages: [MediaLanguage]
    let rejections: [String]

    let qualityWeight: Int
    let releaseWeight: Int

    let infoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case title
        case size
        case age
        case ageMinutes
        case rejected
        case downloadAllowed
        case releaseGroup
        case customFormats
        case customFormatScore
        case network = "protocol"
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
        network == .torrent
    }

    var isUsenet: Bool {
        network == .usenet
    }

    var isFreeleech: Bool {
        cleanIndexerFlags.contains { $0.lowercased().contains("leech") }
    }

    var isScene: Bool {
        cleanIndexerFlags.contains { $0.lowercased().contains("scene") }
    }

    var isNuked: Bool {
        cleanIndexerFlags.contains { $0.lowercased().contains("nuked") }
    }

    var isInternal: Bool {
        cleanIndexerFlags.contains { $0.lowercased().contains("internal") }
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

    var hasOtherFlags: Bool {
        cleanIndexerFlags.contains {
            let flag = $0.lowercased()

            return !flag.contains("leech") && !flag.contains("scene")
                && !flag.contains("nuked") && !flag.contains("internal")
        }
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

    func matches(_ query: String) -> Bool {
        if title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if flagLabels.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        return customFormats?.contains { $0.label.localizedCaseInsensitiveContains(query) } ?? false
    }

    var releaseGroupLabel: String? {
        guard let group = releaseGroup?.trimmed(), !group.isEmpty else { return nil }

        return group
    }

    var flagLabels: [String] {
        var labels: [String] = cleanIndexerFlags

        if isProper {
            labels.append(String(localized: "Proper", comment: "The PROPER flag"))
        }

        if isRepack {
            labels.append(String(localized: "Repack", comment: "The REPACK flag"))
        }

        return labels
    }

    var formatLabels: [String] {
        var labels: [String] = []

        if customFormatScore != 0 {
            labels.append(scoreLabel)
        }

        labels.append(contentsOf: (customFormats ?? []).map(\.label))

        return labels
    }

    var indexerFlagsLabel: String? {
        guard !(indexerFlags ?? []).isEmpty else { return nil }

        return cleanIndexerFlags.formattedList()
    }

    var languageLabel: String {
        if languages.count <= 1 && title.hasMultiLanguageTag {
            return String(localized: "Multilingual")
        }

        return languageSingleLabel(languages)
    }

    var languagesLabel: String {
        if languages.isEmpty {
            return String(localized: "Unknown")
        }

        return languages.map { $0.label }
            .formattedList()
    }

    var typeLabel: String {
        if network == .torrent {
            return "\(network.label) (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        return network.label
    }

    var sizeLabel: String {
        formatSize(size)
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
        formatAge(ageMinutes)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore)
    }

    func bitrateLabel(_ runtime: Int) -> String? {
        guard runtime > 0 else { return nil }

        guard let bitrate = calculateBitrate(runtime * 60, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return "~\(label)"
    }
}
