import Foundation

// The keys of Radarr's movie index filters (`movieActions.js` `filterPredicates` and `filterBuilderProps`).
extension Movie: CustomFilterable {
    /// The `type` of this grid's custom filters on the server.
    static let customFilterType = "movieIndex"

    static let customFilterValues: [String: @Sendable (Movie) -> CustomFilterItemValue?] = [
        "monitored": { .bool($0.monitored) },
        "isAvailable": { .bool($0.isAvailable) },
        "minimumAvailability": { .string($0.minimumAvailability.rawValue) },
        "title": { .string($0.title) },
        "originalLanguage": { .string($0.originalLanguage?.name ?? "") },
        "status": { .string($0.status.rawValue) },
        "studio": { $0.studio.map { .string($0) } },
        "qualityProfileId": { .number(Double($0.qualityProfileId)) },
        "added": { .date($0.added) },
        "year": { .number(Double($0.year)) },
        "inCinemas": { .date($0.inCinemas) },
        "physicalRelease": { .date($0.physicalRelease) },
        "digitalRelease": { .date($0.digitalRelease) },
        "runtime": { .number(Double($0.runtime)) },
        "path": { $0.path.map { .string($0) } },
        "sizeOnDisk": { .number(Double($0.sizeOnDisk ?? 0)) },
        "genres": { .strings($0.genres) },
        "tmdbRating": { .decimal($0.ratings?.tmdb?.value ?? 0, scale: 10) },
        "tmdbVotes": { .number(Double($0.ratings?.tmdb?.votes ?? 0)) },
        "imdbRating": { .decimal($0.ratings?.imdb?.value ?? 0) },
        "imdbVotes": { .number(Double($0.ratings?.imdb?.votes ?? 0)) },
        "rottenTomatoesRating": { .decimal($0.ratings?.rottenTomatoes?.value ?? 0) },
        "traktRating": { .decimal($0.ratings?.trakt?.value ?? 0, scale: 10) },
        "traktVotes": { .number(Double($0.ratings?.trakt?.votes ?? 0)) },
        "popularity": { $0.popularity.map { .decimal($0) } },
        "certification": { $0.certification.map { .string($0) } },
        "tags": { .numbers($0.tags.map(Double.init)) },
    ]
}
