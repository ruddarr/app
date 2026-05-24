import Foundation

struct ProwlarrRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String
    let title: String
    let indexerId: Int
    let indexer: String?

    let size: Int
    let age: Int
    let ageMinutes: Float
    let publishDate: Date?

    let network: ReleaseProtocol
    let seeders: Int?
    let leechers: Int?
    let grabs: Int?

    let categories: [ProwlarrCategoryRef]
    let infoUrl: String?

    enum CodingKeys: String, CodingKey {
        case guid
        case title
        case indexerId
        case indexer
        case size
        case age
        case ageMinutes
        case publishDate
        case network = "protocol"
        case seeders
        case leechers
        case grabs
        case categories
        case infoUrl
    }

    var isTorrent: Bool { network == .torrent }
    var isUsenet: Bool { network == .usenet }

    var indexerLabel: String {
        guard let name = indexer else {
            return String(indexerId)
        }

        return formatIndexer(name)
    }
    var sizeLabel: String { formatBytes(size) }
    var ageLabel: String { formatAge(ageMinutes) }

    var typeLabel: String {
        if network == .torrent {
            return "\(network.label) (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        return network.label
    }
}

struct ProwlarrCategoryRef: Codable, Hashable, Identifiable {
    let id: Int
    let name: String?
}
