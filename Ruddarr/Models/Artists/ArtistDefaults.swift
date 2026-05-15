import Foundation

struct ArtistDefaults {
    let monitor: ArtistMonitorType
    let rootFolder: String
    let qualityProfile: Int
    let metadataProfile: Int

    init(
        monitor: ArtistMonitorType = .none,
        rootFolder: String = "",
        qualityProfile: Int = -1,
        metadataProfile: Int = -1
    ) {
        self.monitor = monitor
        self.rootFolder = rootFolder
        self.qualityProfile = qualityProfile
        self.metadataProfile = metadataProfile
    }

    init(from artist: Artist) {
        monitor = artist.addOptions?.monitor ?? .none
        rootFolder = artist.rootFolderPath ?? ""
        qualityProfile = artist.qualityProfileId ?? -1
        metadataProfile = artist.metadataProfileId ?? -1
    }
}

extension ArtistDefaults: Codable {
    enum CodingKeys: String, CodingKey {
        case monitor
        case rootFolder
        case qualityProfile
        case metadataProfile
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monitor = try values.decode(ArtistMonitorType.self, forKey: .monitor)
        rootFolder = try values.decode(String.self, forKey: .rootFolder)
        qualityProfile = try values.decode(Int.self, forKey: .qualityProfile)
        metadataProfile = try values.decode(Int.self, forKey: .metadataProfile)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monitor, forKey: .monitor)
        try container.encode(rootFolder, forKey: .rootFolder)
        try container.encode(qualityProfile, forKey: .qualityProfile)
        try container.encode(metadataProfile, forKey: .metadataProfile)
    }
}

extension ArtistDefaults: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(ArtistDefaults.self, from: data) else { return nil }
        self = decoded
    }

    var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
