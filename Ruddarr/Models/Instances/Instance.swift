import SwiftUI
import Foundation

// Changing instance properties is risky and can wipe saved cloud data
struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()

    // WARNING: BE CAREFUL CHANGING
    var type: InstanceType = .radarr
    var mode: InstanceMode = .normal
    var label: String = ""
    var url: String = ""
    var alternateURL: String = ""
    var apiKey: String = ""
    var headers: [InstanceHeader] = []
    var rootFolders: [InstanceRootFolder] = []
    var qualityProfiles: [InstanceQualityProfile] = []
    var tags: [Tag] = []
    // WARNING: BE CAREFUL CHANGING

    var name: String?
    var version: String?
    var stats: InstanceStats?

    init(id: UUID = UUID()) {
        self.id = id
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        id = try values.decode(UUID.self, forKey: .id)
        type = try values.decode(InstanceType.self, forKey: .type)
        mode = try values.decode(InstanceMode.self, forKey: .mode)
        label = try values.decode(String.self, forKey: .label)
        url = try values.decode(String.self, forKey: .url)
        apiKey = try values.decode(String.self, forKey: .apiKey)
        headers = try values.decode([InstanceHeader].self, forKey: .headers)
        rootFolders = try values.decode([InstanceRootFolder].self, forKey: .rootFolders)
        qualityProfiles = try values.decode([InstanceQualityProfile].self, forKey: .qualityProfiles)
        tags = try values.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        alternateURL = try values.decodeIfPresent(String.self, forKey: .alternateURL) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name)
        version = try values.decodeIfPresent(String.self, forKey: .version)
        stats = try values.decodeIfPresent(InstanceStats.self, forKey: .stats)
    }

    var configuration: Instance {
        var config = Instance(id: id)
        config.type = type
        config.mode = mode
        config.label = label
        config.url = url
        config.alternateURL = alternateURL
        config.apiKey = apiKey
        config.headers = headers
        config.name = name

        return config
    }

    var contextKey: String {
        "\(type.rawValue.lowercased())-\(id.shortened)"
    }

    var auth: [String: String] {
        var map: [String: String] = [:]

        map["X-Api-Key"] = apiKey

        for header in headers {
            map[header.name] = header.value
        }

        return map
    }

    var candidateURLs: [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for raw in [url, alternateURL] {
            guard var normalized = raw.trimmed().untrailingSlashIt, !normalized.isEmpty else { continue }

            if let canonical = URL(string: normalized)?.absoluteString {
                normalized = canonical
            }

            guard seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }

        return result
    }

    func baseURL() throws -> URL {
        let resolved = InstanceResolver.shared.resolve(self)

        guard let url = URL(string: resolved) else {
            throw API.Error.invalidUrl(resolved)
        }

        return url
    }

    func isPrivateIp(primaryOnly: Bool = false) -> Bool {
        let bases = primaryOnly ? Array(candidateURLs.prefix(1)) : candidateURLs

        return bases.contains { base in
            guard let host = NetworkInterfaces.host(of: base) else { return false }
            return isPrivateIpAddress(host)
        }
    }

    func hasOnlyPrivateIpCandidates() -> Bool {
        let bases = candidateURLs
        guard !bases.isEmpty else { return false }

        return bases.allSatisfy { base in
            guard let host = NetworkInterfaces.host(of: base) else { return false }
            return isPrivateIpAddress(host)
        }
    }

    func timeout(_ call: InstanceTimeout) -> RequestTimeout {
        switch call {
        case .normal: .init(local: 2.5, remote: 10)
        case .sluggish: .init(15)
        case .slow: .init(mode.isSlow ? 300 : 10)
        case .releaseSearch: .init(mode.isSlow ? 180 : 90)
        }
    }
}

extension [Instance] {
    func sameConfiguration(as other: [Instance]) -> Bool {
        map(\.configuration) == other.map(\.configuration)
    }
}

enum InstanceType: String, Identifiable, CaseIterable, Codable {
    case radarr = "Radarr"
    case sonarr = "Sonarr"
    var id: Self { self }
}

enum InstanceMode: Codable {
    case normal
    case slow
    case large // backwards compatible alias of `slow`

    var isSlow: Bool {
        self == .slow || self == .large
    }

    var value: String {
        switch self {
        case .normal: "normal"
        case .slow, .large: "slow"
        }
    }
}

enum InstanceTimeout: Codable {
    case normal
    case sluggish
    case slow
    case releaseSearch
}

struct InstanceHeader: Equatable, Identifiable, Codable {
    var id = UUID()
    var name: String
    var value: String

    init(name: String = "", value: String = "") {
        self.name = name.replacingOccurrences(of: ":", with: "").trimmed()
        self.value = value.trimmed()
    }
}

struct InstanceStatus: Codable {
    let appName: String
    let instanceName: String
    let version: String
}

typealias InstanceRootFolders = InstanceRootFolder

struct InstanceRootFolder: Identifiable, Equatable, Codable, Hashable {
    let id: Int
    let accessible: Bool
    let path: String?
    let freeSpace: Int?

    var label: String {
        path?.untrailingSlashIt ?? "Folder (\(id))"
    }

    func menuLabel(among folders: [InstanceRootFolder]) -> String {
        guard let path = path?.untrailingSlashIt else {
            return "Folder (\(id))"
        }

        let others = folders
            .filter { $0.id != id }
            .compactMap { $0.path?.untrailingSlashIt }

        return RootFolderLabel.disambiguate(path, among: others)
    }

    var labelWithSpace: Text {
        // Allow the path to wrap only after its slashes (zero-width space), so a long
        // path breaks across lines the way a file path naturally reads.
        var string = AttributedString(label.replacingOccurrences(of: "/", with: "/\u{200B}"))

        if let freeSpace {
            string += AttributedString("\u{00A0}\u{00A0}")

            // Keep the free-space value on a single line by joining its words with
            // non-breaking spaces (e.g. "27.6 TB free" never splits mid-value).
            var size = AttributedString(
                String(localized: "\(formatBytes(freeSpace)) free", comment: "%@ = Available disk space")
                    .replacingOccurrences(of: " ", with: "\u{00A0}")
            )

            size.font = .footnote
            size.foregroundColor = .secondary
            string += size
        }

        return Text(string)
    }
}

struct InstanceQualityProfile: Identifiable, Equatable, Codable {
    let id: Int
    let name: String
}

struct InstanceStats: Equatable, Codable {
    let movies: Int
    let series: Int
    let episodes: Int
    let size: Int

    init(movies: [Movie]) {
        self.movies = movies.count
        self.series = 0
        self.episodes = 0
        self.size = movies.reduce(0) { $0 + ($1.sizeOnDisk ?? 0) }
    }

    init(series: [Series]) {
        self.movies = 0
        self.series = series.count
        self.episodes = series.reduce(0) { $0 + $1.episodeFileCount }
        self.size = series.reduce(0) { $0 + ($1.statistics?.sizeOnDisk ?? 0) }
    }

    @concurrent static func make(movies: [Movie]) async -> Self {
        Self(movies: movies)
    }

    @concurrent static func make(series: [Series]) async -> Self {
        Self(series: series)
    }
}

struct InstanceDiskSpace: Identifiable, Equatable, Codable {
    var id: String { path }
    let path: String
    let label: String?
    let freeSpace: Int64
    let totalSpace: Int64

    var displayLabel: String {
        if let label, !label.isEmpty {
            return label
        }

        let trimmed = path.untrailingSlashIt ?? path

        return trimmed.isEmpty ? path : trimmed
    }

    var usedSpace: Int64 {
        max(0, totalSpace - freeSpace)
    }
}

extension Instance {
    static var radarrVoid: Self {
        var instance = Instance(id: UUID(uuidString: "00000000-1000-0000-0000-000000000000")!)
        instance.type = .radarr
        return instance
    }

    static var sonarrVoid: Self {
        var instance = Instance(id: UUID(uuidString: "00000000-2000-0000-0000-000000000000")!)
        instance.type = .sonarr
        return instance
    }

    static var radarrDummy: Self {
        var instance = Instance(id: UUID(uuidString: "00000000-3000-0000-0000-000000000000")!)

        instance.type = .radarr
        instance.label = ".radarr"
        instance.url = "http://10.0.1.5:8310"
        instance.alternateURL = "https://radarr.example.com"
        instance.apiKey = "3b0600c1b3aa42bfb0222f4e13a81f39"
        instance.rootFolders = [
            InstanceRootFolder(id: 1, accessible: true, path: "/volume1/Media/Movies", freeSpace: 1_000_000_000),
            InstanceRootFolder(id: 2, accessible: true, path: "/Media/Films", freeSpace: 50_000_000_000),
        ]
        instance.qualityProfiles = [
            InstanceQualityProfile(id: 1, name: "Any"),
            InstanceQualityProfile(id: 2, name: "4K"),
        ]
        instance.tags = [
            Tag(id: 1, label: "Anime"),
            Tag(id: 2, label: "Trash"),
        ]

        return instance
    }

    static var sonarrDummy: Self {
        var instance = Instance(id: UUID(uuidString: "00000000-4000-0000-0000-000000000000")!)

        instance.type = .sonarr
        instance.label = ".sonarr"
        instance.url = "http://10.0.1.5:8989"
        instance.alternateURL = "https://sonarr.example.com"
        instance.apiKey = "f8e3682b3b984cddbaa00047a09d0fbd"
        instance.rootFolders = [
            InstanceRootFolder(id: 1, accessible: true, path: "/volume1/Media/TV Series", freeSpace: 2_000_000_000),
            InstanceRootFolder(id: 2, accessible: true, path: "/Media/Docuseries", freeSpace: 20_000_000_000),
        ]
        instance.qualityProfiles = [
            InstanceQualityProfile(id: 1, name: "Any"),
            InstanceQualityProfile(id: 2, name: "SD"),
            InstanceQualityProfile(id: 3, name: "720p"),
            InstanceQualityProfile(id: 4, name: "1080p"),
            InstanceQualityProfile(id: 5, name: "4K"),
        ]
        instance.tags = [
            Tag(id: 1, label: "Anime"),
            Tag(id: 2, label: "Trash"),
        ]

        return instance
    }
}
