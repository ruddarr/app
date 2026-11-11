import Foundation

// Sonarr v4's series index filters (`seriesActions.js` `filterBuilderProps` and `filterPredicates`).
// Not offered, because `Series` doesn't decode their data: `releaseGroups`, and the v5 keys
// `averageSizePerEpisode`, `releaseTypes`, `episodeFileQualities` and `episodesMonitoredStatus`.
extension Series: CustomFilterable {
    static let customFilterType = "series"

    static var customFilterHiddenKeys: Set<String> { ["missing"] }

    static let customFilterFields = makeCustomFilterFields()

    private static func makeCustomFilterFields() -> [CustomFilterField] {
        let statuses: [SeriesStatus] = [.continuing, .upcoming, .ended, .deleted]
        let types: [SeriesType] = [.anime, .daily, .standard]

        let monitoredStatuses: [CustomFilterOption] = [
            .init(value: .string("all"), label: String(localized: "All", comment: "Custom filter value: all seasons are monitored")),
            .init(value: .string("partial"), label: String(localized: "Partial", comment: "Custom filter value: some seasons are monitored")),
            .init(value: .string("none"), label: String(localized: "None", comment: "Custom filter value: no seasons are monitored")),
        ]

        return [
            .init(key: "monitored", label: String(localized: "Monitored", comment: "Custom filter field"), builder: .exact, kind: .bool, group: .status),
            .init(
                key: "status", label: String(localized: "Status", comment: "Custom filter field"),
                builder: .exact, kind: .options(statuses.map { .init(value: .string($0.rawValue), label: $0.label) }), group: .status
            ),
            .init(
                key: "seriesType", label: String(localized: "Type", comment: "Custom filter field"),
                builder: .exact, kind: .options(types.map { .init(value: .string($0.rawValue), label: $0.label) }), group: .status
            ),
            .init(key: "title", label: String(localized: "Title", comment: "Custom filter field"), builder: .string, kind: .text, group: .metadata),
            .init(key: "network", label: String(localized: "Network", comment: "Custom filter field"), builder: .array, kind: .libraryValues, group: .metadata),
            .init(key: "qualityProfileId", label: String(localized: "Quality Profile", comment: "Custom filter field"), builder: .exact, kind: .qualityProfile, group: .library),
            .init(key: "nextAiring", label: String(localized: "Next Airing", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "previousAiring", label: String(localized: "Previous Airing", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "added", label: String(localized: "Added", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "seasonCount", label: String(localized: "Season Count", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
            .init(key: "episodeProgress", label: String(localized: "Episode Progress", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
            .init(key: "path", label: String(localized: "Path", comment: "Custom filter field"), builder: .string, kind: .text, group: .library),
            .init(key: "rootFolderPath", label: String(localized: "Root Folder Path", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .library),
            .init(key: "sizeOnDisk", label: String(localized: "Size on Disk", comment: "Custom filter field"), builder: .number, kind: .bytes, group: .library),
            .init(key: "genres", label: String(localized: "Genres", comment: "Custom filter field"), builder: .array, kind: .libraryValues, group: .metadata),
            .init(key: "originalLanguage", label: String(localized: "Original Language", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .metadata),
            .init(key: "ratings", label: String(localized: "Rating", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "ratingVotes", label: String(localized: "Rating Votes", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "certification", label: String(localized: "Certification", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .metadata),
            .init(key: "tags", label: String(localized: "Tags", comment: "Custom filter field"), builder: .array, kind: .tag, group: .library),
            .init(key: "useSceneNumbering", label: String(localized: "Scene Numbering", comment: "Custom filter field"), builder: .exact, kind: .bool, group: .status),
            .init(key: "hasMissingSeason", label: String(localized: "Has Missing Season", comment: "Custom filter field"), builder: .exact, kind: .bool, group: .status),
            .init(
                key: "seasonsMonitoredStatus", label: String(localized: "Seasons Monitored Status", comment: "Custom filter field"),
                builder: .exact, kind: .options(monitoredStatuses), group: .status
            ),
            .init(key: "year", label: String(localized: "Year", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
        ]
    }

    // swiftlint:disable:next cyclomatic_complexity
    func customFilterValue(for key: String) -> CustomFilterItemValue {
        switch key {
        case "monitored": .bool(monitored)
        case "status": .string(status.rawValue)
        case "seriesType": .string(seriesType.rawValue)
        case "title": .string(title)
        case "network": network.map { .string($0) } ?? .missing
        case "qualityProfileId": qualityProfileId.map { .number(Double($0)) } ?? .missing
        case "nextAiring": .date(nextAiring)
        case "previousAiring": .date(previousAiring)
        case "added": .date(added)
        case "seasonCount": .number(Double(statistics?.seasonCount ?? 0))
        case "episodeProgress": .number(episodeProgress)
        case "path": path.map { .string($0) } ?? .missing
        case "rootFolderPath": rootFolderPath.map { .string($0) } ?? .missing
        case "sizeOnDisk": .number(Double(statistics?.sizeOnDisk ?? 0))
        case "genres": .strings(genres)
        case "originalLanguage": .string(originalLanguage?.name ?? "")
        case "ratings": .decimal(ratings?.value ?? 0, scale: 10)
        case "ratingVotes": .number(Double(ratings?.votes ?? 0))
        case "certification": certification.map { .string($0) } ?? .missing
        case "tags": .numbers(tags.map(Double.init))
        case "useSceneNumbering": .bool(useSceneNumbering)
        case "hasMissingSeason": .bool(hasMissingSeason)
        case "seasonsMonitoredStatus": .string(seasonsMonitoredStatus)
        case "year": .number(Double(year))
        case "missing": .result(statistics.map { $0.episodeCount - $0.episodeFileCount > 0 } ?? false)
        default: .unsupported
        }
    }

    /// Downloaded episodes as a percentage of aired, monitored ones; 100 when there are none.
    private var episodeProgress: Double {
        guard let statistics, statistics.episodeCount != 0 else { return 100 }
        return Double(statistics.episodeFileCount) / Double(statistics.episodeCount) * 100
    }

    /// Whether a regular season has aired in full without a single downloaded episode.
    private var hasMissingSeason: Bool {
        seasons.contains { season in
            let episodeFileCount = season.statistics?.episodeFileCount ?? 0
            let episodeCount = season.statistics?.episodeCount ?? 0
            let totalEpisodeCount = season.statistics?.totalEpisodeCount ?? 0

            return season.seasonNumber > 0 && totalEpisodeCount > 0 && episodeCount == totalEpisodeCount && episodeFileCount == 0
        }
    }

    /// `all`, `partial` or `none`, counting regular seasons only.
    private var seasonsMonitoredStatus: String {
        let regular = seasons.filter { $0.seasonNumber > 0 }
        let monitoredCount = regular.count(where: \.monitored)

        if monitoredCount == 0 { return "none" }
        if monitoredCount == regular.count { return "all" }
        return "partial"
    }
}
