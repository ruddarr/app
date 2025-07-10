import Foundation

struct SeriesDefaults {
    let monitor: SeriesMonitorType
    let rootFolder: String
    let seasonFolder: Bool
    let qualityProfile: Int
    let tags: [Int]

    init(
        monitor: SeriesMonitorType = .none,
        rootFolder: String = "",
        seasonFolder: Bool = true,
        qualityProfile: Int = -1
    ) {
        self.monitor = monitor
        self.rootFolder = rootFolder
        self.seasonFolder = seasonFolder
        self.qualityProfile = qualityProfile
        self.tags = []
    }

    init(from series: Series) {
        monitor = series.addOptions?.monitor ?? .none
        rootFolder = series.rootFolderPath ?? ""
        seasonFolder = series.seasonFolder
        qualityProfile = series.qualityProfileId ?? -1
        tags = series.tags
    }
}

extension SeriesDefaults: Codable {
    enum CodingKeys: String, CodingKey {
        case monitor
        case rootFolder
        case seasonFolder
        case qualityProfile
        case tags
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monitor = try values.decode(SeriesMonitorType.self, forKey: .monitor)
        rootFolder = try values.decode(String.self, forKey: .rootFolder)
        seasonFolder = try values.decode(Bool.self, forKey: .seasonFolder)
        qualityProfile = try values.decode(Int.self, forKey: .qualityProfile)
        tags = try values.decode([Int].self, forKey: .tags)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monitor, forKey: .monitor)
        try container.encode(rootFolder, forKey: .rootFolder)
        try container.encode(seasonFolder, forKey: .seasonFolder)
        try container.encode(qualityProfile, forKey: .qualityProfile)
        try container.encode(tags, forKey: .tags)
    }
}

extension SeriesDefaults: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(SeriesDefaults.self, from: data) else { return nil }
        self = decoded
    }

    var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
