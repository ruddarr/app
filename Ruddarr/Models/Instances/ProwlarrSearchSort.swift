import SwiftUI

struct ProwlarrSearchSort: Equatable {
    var isAscending: Bool = false
    var option: Option = .byRelevance

    var network: String = .all
    var indexer: String = .all

    static func == (lhs: ProwlarrSearchSort, rhs: ProwlarrSearchSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.network == rhs.network &&
        lhs.indexer == rhs.indexer
    }

    enum Option: Codable, Hashable, Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance
        case bySeeders
        case byFilesize
        case byAge
        case byGrabs

        var label: some View {
            switch self {
            case .byRelevance: Label(String(localized: "Relevance", comment: "Prowlarr search sort option"), systemImage: "sparkle")
            case .bySeeders: Label(String(localized: "Seeders", comment: "Release filter"), systemImage: "person.wave.2")
            case .byFilesize: Label(String(localized: "File Size", comment: "Release filter"), systemImage: "internaldrive")
            case .byAge: Label(String(localized: "Age", comment: "Release filter"), systemImage: "calendar")
            case .byGrabs: Label(String(localized: "Grabs"), systemImage: "arrow.down.circle")
            }
        }

        func isOrderedBefore(_ lhs: ProwlarrRelease, _ rhs: ProwlarrRelease) -> Bool {
            switch self {
            case .byRelevance:
                preconditionFailure("byRelevance is handled by the early-return in filterAndSortItems")
            case .bySeeders:
                lhs.seeders ?? 0 > rhs.seeders ?? 0
            case .byFilesize:
                lhs.size > rhs.size
            case .byAge:
                lhs.ageMinutes > rhs.ageMinutes
            case .byGrabs:
                lhs.grabs ?? 0 > rhs.grabs ?? 0
            }
        }
    }

    var hasFilter: Bool {
        network != .all || indexer != .all
    }

    mutating func resetFilters() {
        network = .all
        indexer = .all
    }

    func filterAndSortItems(_ items: [ProwlarrRelease]) -> [ProwlarrRelease] {
        let filtered = items.filter { release in
            [release.network.label, .all].contains(network) &&
            [release.indexerLabel, .all].contains(indexer)
        }

        if option == .byRelevance {
            return filtered
        }

        let comparator = option.isOrderedBefore

        return filtered.sorted {
            isAscending ? comparator($1, $0) : comparator($0, $1)
        }
    }
}

extension ProwlarrSearchSort: RawRepresentable {
    init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            self = try JSONDecoder().decode(ProwlarrSearchSort.self, from: data)
        } catch {
            leaveBreadcrumb(.fatal, category: "prowlarr.search.sort", message: "JSON decode failed: \(error)", data: ["error": error])
            self = .init()
        }
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return result
    }
}

extension ProwlarrSearchSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case network
        case indexer
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            network: container.decode(String.self, forKey: .network),
            indexer: container.decode(String.self, forKey: .indexer)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(network, forKey: .network)
        try container.encode(indexer, forKey: .indexer)
    }
}
