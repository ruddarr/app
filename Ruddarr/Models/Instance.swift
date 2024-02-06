import Foundation

struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()
    var type: InstanceType = .radarr
    var label: String = ""
    var url: String = ""
    var apiKey: String = ""

    var rootFolders: [InstanceRootFolders] = []
    var qualityProfiles: [InstanceQualityProfile] = []
}

enum InstanceType: String, Identifiable, CaseIterable, Codable {
    case radarr = "Radarr"
    case sonarr = "Sonarr"
    var id: Self { self }
}

struct InstanceStatus: Codable {
  let appName: String
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

    static var till: Self {
        .init(
            id: UUID(uuidString: "f8a124e4-e7d8-405a-b38e-cab1005fc2dd")!,
            type: .radarr,
            url: "HTTP://10.0.1.5:8310/api",
            apiKey: "8f45bce99e254f888b7a2ba122468dbe"
        )
    }

    static var digitalOcean: Self {
        .init(
            id: UUID(uuidString: "6cd49e6e-fbb2-40c3-9f22-f4025c070ae5")!,
            type: .radarr,
            url: "http://167.172.20.216:7878",
            apiKey: "b3216ceaa69341619b1b56377607972c"
        )
    }

    static var sample: Self {
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            type: .radarr,
            label: ".sample",
            url: "http://10.0.1.5:8310",
            apiKey: "8f45bce99e254f888b7a2ba122468dbe",
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
