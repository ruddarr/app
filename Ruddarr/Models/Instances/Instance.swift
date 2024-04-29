import SwiftUI
import Foundation

struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()

    var type: InstanceType = .radarr
    var mode: InstanceMode = .normal
    var label: String = ""
    var url: String = ""
    var apiKey: String = ""
    var headers: [InstanceHeader] = []

    var version: String = ""

    var rootFolders: [InstanceRootFolders] = []
    var qualityProfiles: [InstanceQualityProfile] = []

    var auth: [String: String] {
        var map: [String: String] = [:]

        map["Authorization"] = "Bearer \(apiKey)"

        for header in headers {
            map[header.name] = header.value
        }

        return map
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
        case .slow: mode == .large ? 180 : 10
        case .releaseSearch: 60
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
    case large
}

enum InstanceTimeout: Codable {
    case normal
    case slow
    case releaseSearch
    case releaseDownload
}

struct InstanceHeader: Equatable, Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var value: String = ""
}

struct InstanceStatus: Codable {
    let appName: String
    let version: String
    let authentication: String
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

struct RadarrCommand: Codable {
    let name: Command
    let movieIds: [Int]

    enum Command: String, Codable {
        case refresh = "RefreshMovie"
        case automaticSearch = "MoviesSearch"
    }
}

extension Instance {
    static var void: Self {
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            type: .radarr
        )
    }

    static var sample: Self {
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            type: .radarr,
            label: ".sample",
            url: "http://10.0.1.5:8310",
            apiKey: "3b0600c1b3aa42bfb0222f4e13a81f39",
            rootFolders: [
                InstanceRootFolders(id: 1, accessible: true, path: "/volume1/Media/Movies", freeSpace: 1_000_000_000),
            ],
            qualityProfiles: [
                InstanceQualityProfile(id: 1, name: "Any"),
                InstanceQualityProfile(id: 2, name: "4K"),
            ]
        )
    }
}
