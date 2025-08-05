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
    var apiKey: String = ""
    var headers: [InstanceHeader] = []
    var rootFolders: [InstanceRootFolders] = []
    var qualityProfiles: [InstanceQualityProfile] = []
    var tags: [Tag] = []
    // WARNING: BE CAREFUL CHANGING

    var name: String?
    var version: String?

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
        rootFolders = try values.decode([InstanceRootFolders].self, forKey: .rootFolders)
        qualityProfiles = try values.decode([InstanceQualityProfile].self, forKey: .qualityProfiles)
        tags = try values.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        name = try values.decodeIfPresent(String.self, forKey: .name)
        version = try values.decodeIfPresent(String.self, forKey: .version)
    }

    var auth: [String: String] {
        var map: [String: String] = [:]

        map["X-Api-Key"] = apiKey

        for header in headers {
            map[header.name] = header.value
        }

        return map
    }

    func baseURL() throws -> URL {
        guard let url = URL(string: url) else {
            throw API.Error.invalidUrl(url)
        }

        return url
    }

    func isPrivateIp() -> Bool {
        guard let instanceUrl = URL(string: url) else {
            return false
        }

        return isPrivateIpAddress(instanceUrl.host() ?? "")
    }

    func timeout(_ call: InstanceTimeout) -> Double {
        switch call {
        case .normal: 10
        case .slow: mode.isSlow ? 300 : 10
        case .releaseSearch: mode.isSlow ? 180 : 90
        case .releaseDownload: 15
        }
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
        case .normal: return "normal"
        case .slow, .large: return "slow"
        }
    }
}

enum InstanceTimeout: Codable {
    case normal
    case slow
    case releaseSearch
    case releaseDownload
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

struct InstanceRootFolders: Identifiable, Equatable, Codable {
    let id: Int
    let accessible: Bool
    let path: String?
    let freeSpace: Int?

    var label: String {
        path?.untrailingSlashIt ?? "Folder (\(id))"
    }
}

struct InstanceQualityProfile: Identifiable, Equatable, Codable {
    let id: Int
    let name: String
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
        instance.apiKey = "3b0600c1b3aa42bfb0222f4e13a81f39"
        instance.rootFolders = [
            InstanceRootFolders(id: 1, accessible: true, path: "/volume1/Media/Movies", freeSpace: 1_000_000_000),
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
        instance.apiKey = "f8e3682b3b984cddbaa00047a09d0fbd"
        instance.rootFolders = [
            InstanceRootFolders(id: 1, accessible: true, path: "/volume1/Media/TV Series", freeSpace: 2_000_000_000),
            InstanceRootFolders(id: 2, accessible: true, path: "/volume2/Media/Docuseries", freeSpace: 2_000_000_000),
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
