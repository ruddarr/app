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
}

struct InstanceQualityProfile: Identifiable, Equatable, Codable {
    let id: Int
    let name: String
}

extension Instance {
    static var sample: Self {
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            label: ".sample",
            url: "http://10.0.1.5:8310",
            apiKey: "8f45bce99e254f888b7a2ba122468dbe"
        )
    }
}
