import Foundation

struct BookDefaults {
    let rootFolder: String
    let qualityProfile: Int
    let metadataProfile: Int
    let monitorNewBooks: Bool

    init(
        rootFolder: String = "",
        qualityProfile: Int = -1,
        metadataProfile: Int = -1,
        monitorNewBooks: Bool = false
    ) {
        self.rootFolder = rootFolder
        self.qualityProfile = qualityProfile
        self.metadataProfile = metadataProfile
        self.monitorNewBooks = monitorNewBooks
    }

    init(from book: Book) {
        rootFolder = book.audiobookRootFolderPath
        qualityProfile = book.audiobookQualityProfileId
        metadataProfile = book.audiobookMetadataProfileId
        monitorNewBooks = book.audiobookMonitorFuture
    }
}

extension BookDefaults: Codable {
    enum CodingKeys: String, CodingKey {
        case rootFolder
        case qualityProfile
        case metadataProfile
        case monitorNewBooks
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rootFolder = try values.decodeIfPresent(String.self, forKey: .rootFolder) ?? ""
        qualityProfile = try values.decodeIfPresent(Int.self, forKey: .qualityProfile) ?? -1
        metadataProfile = try values.decodeIfPresent(Int.self, forKey: .metadataProfile) ?? -1
        monitorNewBooks = try values.decodeIfPresent(Bool.self, forKey: .monitorNewBooks) ?? false
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootFolder, forKey: .rootFolder)
        try container.encode(qualityProfile, forKey: .qualityProfile)
        try container.encode(metadataProfile, forKey: .metadataProfile)
        try container.encode(monitorNewBooks, forKey: .monitorNewBooks)
    }
}

extension BookDefaults: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(BookDefaults.self, from: data) else { return nil }
        self = decoded
    }

    var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
