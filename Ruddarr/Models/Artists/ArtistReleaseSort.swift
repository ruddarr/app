import SwiftUI

struct ArtistReleaseSort: Equatable {
    var isAscending: Bool = true
    var option: Option = .byWeight
    var search: String = ""

    var indexer: String = .all
    var quality: String = .all
    var network: String = .all
    var customFormat: String = .all

    var approved: Bool = false

    static func == (lhs: ArtistReleaseSort, rhs: ArtistReleaseSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.search == rhs.search &&

        lhs.indexer == rhs.indexer &&
        lhs.quality == rhs.quality &&
        lhs.network == rhs.network &&
        lhs.customFormat == rhs.customFormat &&

        lhs.approved == rhs.approved
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
            case .byWeight: Label("Weight", systemImage: "scalemass")
            case .byQuality: Label("Quality", systemImage: "slider.horizontal.3")
            case .bySeeders: Label("Seeders", systemImage: "person.wave.2")
            case .byFilesize: Label("File Size", systemImage: "internaldrive")
            case .byAge: Label("Age", systemImage: "calendar")
            case .byCustomScore: Label("Custom Score", systemImage: "person.badge.plus")
            }
        }

        func isOrderedBefore(_ lhs: ArtistRelease, _ rhs: ArtistRelease) -> Bool {
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
                lhs.quality.quality.normalizedName > rhs.quality.quality.normalizedName
            case .byCustomScore:
                lhs.customFormatScore > rhs.customFormatScore
            }
        }
    }

    var hasFilter: Bool {
        network != .all
        || indexer != .all
        || quality != .all
        || customFormat != .all
        || approved
    }

    mutating func resetFilters() {
        network = .all
        indexer = .all
        quality = .all
        customFormat = .all
        approved = false
    }

    func filterAndSortItems(_ items: [ArtistRelease]) -> [ArtistRelease] {
        let query = search.trimmed()
        let comparator = option.isOrderedBefore

        return items
            .filter { release in
                (search.isEmpty || release.title.localizedCaseInsensitiveContains(query)) &&
                [release.network.label, .all].contains(network) &&
                [release.indexerLabel, .all].contains(indexer) &&
                [release.quality.quality.normalizedName, .all].contains(quality) &&
                (customFormat == .all || release.customFormats?.contains { $0.name == customFormat } ?? false) &&
                (!approved || !release.rejected)
            }
            .sorted {
                isAscending ? comparator($1, $0) : comparator($0, $1)
            }
    }

}

extension ArtistReleaseSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(ArtistReleaseSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "artist.releases.sort", message: "JSON decode failed: \(error)", data: ["error": error])

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

extension ArtistReleaseSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case search

        case indexer
        case quality
        case network
        case customFormat

        case approved
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            search: container.decode(String.self, forKey: .search),
            indexer: container.decode(String.self, forKey: .indexer),
            quality: container.decode(String.self, forKey: .quality),
            network: container.decode(String.self, forKey: .network),
            customFormat: container.decode(String.self, forKey: .customFormat),
            approved: container.decode(Bool.self, forKey: .approved),
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(search, forKey: .search)
        try container.encode(indexer, forKey: .indexer)
        try container.encode(quality, forKey: .quality)
        try container.encode(network, forKey: .network)
        try container.encode(customFormat, forKey: .customFormat)
        try container.encode(approved, forKey: .approved)
    }
}
