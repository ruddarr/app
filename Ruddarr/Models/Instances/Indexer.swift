import Foundation

struct Indexer: Identifiable, Equatable, Hashable, Codable {
    let id: Int
    let name: String
    let definitionName: String?
    let description: String?
    var enable: Bool
    let `protocol`: IndexerProtocol
    let privacy: IndexerPrivacy
    let priority: Int
    let language: String?
    let added: Date?
    let appProfileId: Int?
    let tags: [Int]
    let capabilities: IndexerCapabilities?
}

enum IndexerProtocol: String, Codable, Hashable {
    case torrent
    case usenet
    case unknown

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = IndexerProtocol(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .torrent: String(localized: "Torrent")
        case .usenet: String(localized: "Usenet")
        case .unknown: String(localized: "Unknown")
        }
    }
}

enum IndexerPrivacy: String, Codable, Hashable {
    case `public`
    case `private`
    case semiPrivate
    case unknown

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = IndexerPrivacy(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .public: String(localized: "Public")
        case .private: String(localized: "Private")
        case .semiPrivate: String(localized: "Semi-Private")
        case .unknown: String(localized: "Unknown")
        }
    }
}

struct IndexerCapabilities: Codable, Equatable, Hashable {
    let limitsMax: Int?
    let limitsDefault: Int?
    let categories: [IndexerCategory]?
    let supportsRawSearch: Bool?
}

struct IndexerCategory: Codable, Equatable, Hashable, Identifiable {
    let id: Int
    let name: String
    let subCategories: [IndexerCategory]?
}

struct IndexerBulkResource: Codable {
    let ids: [Int]
    let enable: Bool
}
