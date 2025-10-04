import SwiftUI

struct MovieReleaseSort: Equatable {
    var isAscending: Bool = true
    var option: Option = .byWeight
    var search: String = ""

    var indexer: String = ".all"
    var quality: String = ".all"
    var language: String = ".all"
    var network: String = ".all"
    var customFormat: String = ".all"

    var approved: Bool = false
    var freeleech: Bool = false
    var originalLanguage: Bool = false

    static func == (lhs: MovieReleaseSort, rhs: MovieReleaseSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.search == rhs.search &&

        lhs.indexer == rhs.indexer &&
        lhs.quality == rhs.quality &&
        lhs.language == rhs.language &&
        lhs.network == rhs.network &&
        lhs.customFormat == rhs.customFormat &&

        lhs.approved == rhs.approved &&
        lhs.freeleech == rhs.freeleech &&
        lhs.originalLanguage == rhs.originalLanguage
    }

    enum Option: Codable, Hashable, Identifiable, CaseIterable {
        var id: Self { self }

        case byWeight
        case byAge
        case byQuality
        case bySeeders
        case byFilesize
        case byCustomScore

        var label: some View {
            switch self {
            case .byWeight: Label(String(localized: "Weight", comment: "Release filter"), systemImage: "scalemass")
            case .byQuality: Label(String(localized: "Quality", comment: "Release filter"), systemImage: "slider.horizontal.3")
            case .bySeeders: Label(String(localized: "Seeders", comment: "Release filter"), systemImage: "person.wave.2")
            case .byFilesize: Label(String(localized: "File Size", comment: "Release filter"), systemImage: "internaldrive")
            case .byAge: Label(String(localized: "Age", comment: "Release filter"), systemImage: "calendar")
            case .byCustomScore: Label(String(localized: "Custom Score", comment: "Release filter"), systemImage: "person.badge.plus")
            }
        }

        func isOrderedBefore(_ lhs: MovieRelease, _ rhs: MovieRelease) -> Bool {
            switch self {
            case .byWeight:
                lhs.releaseWeight > rhs.releaseWeight
            case .bySeeders:
                lhs.seeders ?? 0 > rhs.seeders ?? 0
            case .byAge:
                lhs.ageMinutes > rhs.ageMinutes
            case .byFilesize:
                lhs.size > rhs.size
            case .byQuality:
                lhs.quality.quality.resolution > rhs.quality.quality.resolution
            case .byCustomScore:
                lhs.customFormatScore > rhs.customFormatScore
            }
        }
    }

    var hasFilter: Bool {
        network != ".all"
        || indexer != ".all"
        || quality != ".all"
        || language != ".all"
        || customFormat != ".all"
        || approved
        || freeleech
        || originalLanguage
    }

    mutating func resetFilters() {
        network = ".all"
        indexer = ".all"
        quality = ".all"
        language = ".all"
        customFormat = ".all"
        approved = false
        freeleech = false
        originalLanguage = false
    }

    func filterAndSortItems(_ items: [MovieRelease], _ movie: Movie) -> [MovieRelease] {
        let query = search.trimmed()
        let comparator = option.isOrderedBefore

        return items
            .filter { release in
                (search.isEmpty || release.title.localizedCaseInsensitiveContains(query)) &&
                [release.network.label, ".all"].contains(network) &&
                [release.indexerLabel, ".all"].contains(indexer) &&
                [release.quality.quality.normalizedName, ".all"].contains(quality) &&
                (language != ".multi" || (release.languages.count > 1 || release.title.lowercased().contains("multi"))) &&
                ([".all", ".multi"].contains(language) || release.languages.contains { $0.label == language }) &&
                (customFormat == ".all" || release.customFormats?.contains { $0.name == customFormat } ?? false) &&
                (!approved || !release.rejected) &&
                (!freeleech || release.cleanIndexerFlags.contains { $0.lowercased().contains("freeleech") }) &&
                (!originalLanguage || release.languages.contains { $0.id == movie.originalLanguage?.id })
            }
            .sorted {
                isAscending ? comparator($1, $0) : comparator($0, $1)
            }
    }
}

extension MovieReleaseSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(MovieReleaseSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "movie.releases.sort", message: "init failed", data: ["error": error])

            self = .init()
        }
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return result
    }
}

 extension MovieReleaseSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case search

        case indexer
        case quality
        case language
        case network
        case customFormat

        case approved
        case freeleech
        case originalLanguage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            search: container.decode(String.self, forKey: .search),
            indexer: container.decode(String.self, forKey: .indexer),
            quality: container.decode(String.self, forKey: .quality),
            language: container.decode(String.self, forKey: .language),
            network: container.decode(String.self, forKey: .network),
            customFormat: container.decode(String.self, forKey: .customFormat),
            approved: container.decode(Bool.self, forKey: .approved),
            freeleech: container.decode(Bool.self, forKey: .freeleech),
            originalLanguage: container.decode(Bool.self, forKey: .originalLanguage)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(search, forKey: .search)
        try container.encode(indexer, forKey: .indexer)
        try container.encode(quality, forKey: .quality)
        try container.encode(language, forKey: .language)
        try container.encode(network, forKey: .network)
        try container.encode(customFormat, forKey: .customFormat)
        try container.encode(approved, forKey: .approved)
        try container.encode(freeleech, forKey: .freeleech)
        try container.encode(originalLanguage, forKey: .originalLanguage)
    }
 }
