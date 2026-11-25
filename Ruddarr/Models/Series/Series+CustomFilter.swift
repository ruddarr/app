import Foundation

extension Series: CustomFilterable {
    static let customFilterType = "series"

    static let customFilterValues: [String: @Sendable (Series) -> CustomFilterItemValue?] = [
        "monitored": { .bool($0.monitored) },
        "status": { .string($0.status.rawValue) },
        "seriesType": { .string($0.seriesType.rawValue) },
        "title": { .string($0.title) },
        "network": { $0.network.map { .string($0) } },
        "qualityProfileId": { $0.qualityProfileId.map { .number(Double($0)) } },
        "nextAiring": { .date($0.nextAiring) },
        "previousAiring": { .date($0.previousAiring) },
        "added": { .date($0.added) },
        "seasonCount": { .number(Double($0.statistics?.seasonCount ?? 0)) },
        "path": { $0.path.map { .string($0) } },
        "rootFolderPath": { $0.rootFolderPath.map { .string($0) } },
        "sizeOnDisk": { .number(Double($0.statistics?.sizeOnDisk ?? 0)) },
        "genres": { .strings($0.genres) },
        "originalLanguage": { .string($0.originalLanguage?.name ?? "") },
        "ratings": { .decimal($0.ratings?.value ?? 0, scale: 10) },
        "ratingVotes": { .number(Double($0.ratings?.votes ?? 0)) },
        "certification": { $0.certification.map { .string($0) } },
        "tags": { .numbers($0.tags.map(Double.init)) },
        "releaseGroups": { .strings($0.statistics?.releaseGroups ?? []) },
        "useSceneNumbering": { .bool($0.useSceneNumbering) },
        "year": { .number(Double($0.year)) },
        "episodeProgress": { .number($0.episodeProgress) },
        "averageSizePerEpisode": { .number($0.averageSizePerEpisode) },
        "hasMissingSeason": { .bool($0.hasMissingSeason) },
        "seasonsMonitoredStatus": { .string($0.seasonsMonitoredStatus) },
    ]
}

private extension Series {
    var episodeProgress: Double {
        episodeCount > 0 ? Double(episodeFileCount) / Double(episodeCount) * 100 : 100
    }

    var averageSizePerEpisode: Double {
        episodeFileCount > 0 ? Double(statistics?.sizeOnDisk ?? 0) / Double(episodeFileCount) : 0
    }

    var hasMissingSeason: Bool {
        seasons.contains { season in
            guard let stats = season.statistics else { return false }

            return season.seasonNumber > 0
                && stats.totalEpisodeCount > 0
                && stats.episodeCount == stats.totalEpisodeCount
                && stats.episodeFileCount == 0
        }
    }

    var seasonsMonitoredStatus: String {
        let regular = seasons.filter { $0.seasonNumber > 0 }
        let monitored = regular.filter(\.monitored).count

        if monitored == 0 { return "none" }

        return monitored == regular.count ? "all" : "partial"
    }
}
