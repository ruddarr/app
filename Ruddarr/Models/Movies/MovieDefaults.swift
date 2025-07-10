import Foundation

struct MovieDefaults {
    let monitored: Bool
    let rootFolder: String
    let qualityProfile: Int
    let tags: [Int]
    let minimumAvailability: MovieStatus

    init(
        monitored: Bool = false,
        rootFolder: String = "",
        qualityProfile: Int = -1,
        tags: [Int] = [],
        minimumAvailability: MovieStatus = .announced
    ) {
        self.monitored = monitored
        self.rootFolder = rootFolder
        self.qualityProfile = qualityProfile
        self.tags = tags
        self.minimumAvailability = minimumAvailability
    }

    init(from movie: Movie) {
        monitored = movie.monitored
        rootFolder = movie.rootFolderPath ?? ""
        tags = movie.tags
        qualityProfile = movie.qualityProfileId
        minimumAvailability = movie.minimumAvailability
    }
}

extension MovieDefaults: Codable {
    enum CodingKeys: String, CodingKey {
        case monitored
        case rootFolder
        case qualityProfile
        case tags
        case minimumAvailability
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monitored = try values.decode(Bool.self, forKey: .monitored)
        rootFolder = try values.decode(String.self, forKey: .rootFolder)
        qualityProfile = try values.decode(Int.self, forKey: .qualityProfile)
        tags = try values.decode([Int].self, forKey: .tags)
        minimumAvailability = try values.decode(MovieStatus.self, forKey: .minimumAvailability)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monitored, forKey: .monitored)
        try container.encode(rootFolder, forKey: .rootFolder)
        try container.encode(qualityProfile, forKey: .qualityProfile)
        try container.encode(tags, forKey: .tags)
        try container.encode(minimumAvailability, forKey: .minimumAvailability)
    }
}

extension MovieDefaults: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(MovieDefaults.self, from: data) else { return nil }
        self = decoded
    }

    var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
