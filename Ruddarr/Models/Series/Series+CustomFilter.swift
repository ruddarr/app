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
        "useSceneNumbering": { .bool($0.useSceneNumbering) },
        "year": { .number(Double($0.year)) },
    ]
}
