import Foundation

// Radarr's movie index filters (`movieIndexActions.js` `filterBuilderProps`, `movieActions.js` `filterPredicates`).
// Not offered, because `Movie` doesn't decode their data: `originalTitle`, `releaseGroups`, `movieFileQualities`,
// `collection`, `releaseDate`, `keywords` and `qualityCutoffNotMet`.
extension Movie: CustomFilterable {
    static let customFilterType = "movieIndex"

    static var customFilterHiddenKeys: Set<String> { ["hasFile"] }

    static let customFilterFields = makeCustomFilterFields()

    private static func makeCustomFilterFields() -> [CustomFilterField] {
        let availability: [MovieStatus] = [.announced, .inCinemas, .released]
        let statuses: [MovieStatus] = [.tba, .announced, .inCinemas, .released, .deleted]

        return [
            .init(key: "monitored", label: String(localized: "Monitored", comment: "Custom filter field"), builder: .exact, kind: .bool, group: .status),
            .init(key: "isAvailable", label: String(localized: "Considered Available", comment: "Custom filter field"), builder: .exact, kind: .bool, group: .status),
            .init(
                key: "minimumAvailability", label: String(localized: "Minimum Availability", comment: "Custom filter field"),
                builder: .exact, kind: .options(availability.map { .init(value: .string($0.rawValue), label: $0.label) }), group: .status
            ),
            .init(key: "title", label: String(localized: "Title", comment: "Custom filter field"), builder: .string, kind: .text, group: .metadata),
            .init(key: "originalLanguage", label: String(localized: "Original Language", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .metadata),
            .init(
                key: "status", label: String(localized: "Release Status", comment: "Custom filter field"),
                builder: .exact, kind: .options(statuses.map { .init(value: .string($0.rawValue), label: $0.label) }), group: .status
            ),
            .init(key: "studio", label: String(localized: "Studio", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .metadata),
            .init(key: "qualityProfileId", label: String(localized: "Quality Profile", comment: "Custom filter field"), builder: .exact, kind: .qualityProfile, group: .library),
            .init(key: "added", label: String(localized: "Added", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "year", label: String(localized: "Year", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
            .init(key: "inCinemas", label: String(localized: "In Cinemas", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "physicalRelease", label: String(localized: "Physical Release", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "digitalRelease", label: String(localized: "Digital Release", comment: "Custom filter field"), builder: .date, kind: .date, group: .dates),
            .init(key: "runtime", label: String(localized: "Runtime", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
            .init(key: "path", label: String(localized: "Path", comment: "Custom filter field"), builder: .string, kind: .text, group: .library),
            .init(key: "sizeOnDisk", label: String(localized: "Size on Disk", comment: "Custom filter field"), builder: .number, kind: .bytes, group: .library),
            .init(key: "genres", label: String(localized: "Genres", comment: "Custom filter field"), builder: .array, kind: .libraryValues, group: .metadata),
            .init(key: "tmdbRating", label: String(localized: "TMDb Rating", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "tmdbVotes", label: String(localized: "TMDb Votes", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "imdbRating", label: String(localized: "IMDb Rating", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "imdbVotes", label: String(localized: "IMDb Votes", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(
                key: "rottenTomatoesRating", label: String(localized: "Rotten Tomatoes Rating", comment: "Custom filter field"),
                builder: .number, kind: .number, group: .ratings
            ),
            .init(key: "traktRating", label: String(localized: "Trakt Rating", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "traktVotes", label: String(localized: "Trakt Votes", comment: "Custom filter field"), builder: .number, kind: .number, group: .ratings),
            .init(key: "popularity", label: String(localized: "Popularity", comment: "Custom filter field"), builder: .number, kind: .number, group: .metadata),
            .init(key: "certification", label: String(localized: "Certification", comment: "Custom filter field"), builder: .exact, kind: .libraryValues, group: .metadata),
            .init(key: "tags", label: String(localized: "Tags", comment: "Custom filter field"), builder: .array, kind: .tag, group: .library),
        ]
    }

    // swiftlint:disable:next cyclomatic_complexity
    func customFilterValue(for key: String) -> CustomFilterItemValue {
        switch key {
        case "monitored": .bool(monitored)
        case "isAvailable": .bool(isAvailable)
        case "minimumAvailability": .string(minimumAvailability.rawValue)
        case "title": .string(title)
        case "originalLanguage": .string(originalLanguage?.name ?? "")
        case "status": .string(status.rawValue)
        case "studio": studio.map { .string($0) } ?? .missing
        case "qualityProfileId": .number(Double(qualityProfileId))
        case "added": .date(added)
        case "year": .number(Double(year))
        case "inCinemas": .date(inCinemas)
        case "physicalRelease": .date(physicalRelease)
        case "digitalRelease": .date(digitalRelease)
        case "runtime": .number(Double(runtime))
        case "path": path.map { .string($0) } ?? .missing
        case "sizeOnDisk": .number(Double(sizeOnDisk ?? 0))
        case "genres": .strings(genres)
        case "tmdbRating": .decimal(ratings?.tmdb?.value ?? 0, scale: 10)
        case "tmdbVotes": .number(Double(ratings?.tmdb?.votes ?? 0))
        case "imdbRating": .decimal(ratings?.imdb?.value ?? 0)
        case "imdbVotes": .number(Double(ratings?.imdb?.votes ?? 0))
        case "rottenTomatoesRating": .decimal(ratings?.rottenTomatoes?.value ?? 0)
        case "traktRating": .decimal(ratings?.trakt?.value ?? 0, scale: 10)
        case "traktVotes": .number(Double(ratings?.trakt?.votes ?? 0))
        case "popularity": popularity.map { .decimal($0) } ?? .missing
        case "certification": certification.map { .string($0) } ?? .missing
        case "tags": .numbers(tags.map(Double.init))
        case "hasFile": hasFile.map { .bool($0) } ?? .missing
        default: .unsupported
        }
    }
}
