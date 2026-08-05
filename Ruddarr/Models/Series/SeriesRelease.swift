import Foundation

struct SeriesRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String
    let title: String
    let seriesTitle: String?
    let size: Int
    let age: Int
    let ageMinutes: Float
    let rejected: Bool
    let downloadAllowed: Bool
    let releaseGroup: String?

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    let network: ReleaseProtocol
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
        case title
        case seriesTitle
        case size
        case age
        case ageMinutes
        case rejected
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
        network == .torrent
    }

    var isUsenet: Bool {
        network == .usenet
    }

    var isFreeleech: Bool {
        releaseFlags.contains { [.freeleech, .halfleech, .freeleech75, .freeleech25].contains($0) }
    }

    var isScene: Bool {
        releaseFlags.contains(.scene)
    }

    var isNuked: Bool {
        releaseFlags.contains(.nuked)
    }

    var isInternal: Bool {
        releaseFlags.contains(.internal)
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
        releaseFlags.contains {
            ![.freeleech, .halfleech, .freeleech75, .freeleech25, .nuked].contains($0)
        }
    }

    var releaseFlags: [SeriesReleaseFlag] {
        guard let flags = indexerFlags, flags > 0 else {
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
        var labels: [String] = releaseFlags.map(\.label)

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

        if let score = scoreLabel, customFormatScore != 0 {
            labels.append(score)
        }

        labels.append(contentsOf: (customFormats ?? []).map(\.label))

        return labels
    }

    var episodeCount: Int {
        if let numbers = mappedEpisodeNumbers, !numbers.isEmpty {
            return numbers.count
        }

        if let numbers = episodeNumbers, !numbers.isEmpty {
            return numbers.count
        }

        return fullSeason ? 0 : 1
    }

    var languageLabel: String {
        if (languages ?? []).count <= 1 && title.hasMultiLanguageTag {
            return String(localized: "Multilingual")
        }

        return languageSingleLabel(languages ?? [])
    }

    var languagesLabel: String {
        guard let langs = languages, !langs.isEmpty else {
            return String(localized: "Unknown")
        }

        return langs.map { $0.label }.formattedList()
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

    func runtime(seriesRuntime: Int, episodeRuntime: (Episode.ID) -> Int?) -> Int {
        if let episodes = mappedEpisodeInfo, !episodes.isEmpty {
            return episodes
                .map { episodeRuntime($0.id) ?? seriesRuntime }
                .reduce(0, +)
        }

        return seriesRuntime * episodeCount
    }

    func bitrateLabel(_ runtime: Int) -> String? {
        guard runtime > 0 else { return nil }

        guard let bitrate = calculateBitrate(runtime * 60, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return "~\(label)"
    }
}

struct SeriesReleaseEpisode: Codable {
    let id: Episode.ID
    let seasonNumber: Season.ID
    let episodeNumber: Episode.ID
    let title: String?
}
