import SwiftUI

struct MovieReleaseSort: Equatable {
    var isAscending: Bool = true
    var option: Option = .byWeight
    var query: String = ""

    var indexer: String = ".all"
    var quality: String = ".all"
    var language: String = ".all"
    var type: String = ".all"
    var customFormat: String = ".all"

    var approved: Bool = false
    var freeleech: Bool = false
    var originalLanguage: Bool = false

    enum Option: Codable, Hashable, Identifiable, CaseIterable {
        var id: Self { self }

        case byWeight
        case byAge
        case byQuality
        case bySeeders
        case byFilesize
        case byCustomScore

        var label: some View {
            switch self {
            case .byWeight: Label(String(localized: "Weight", comment: "Release filter"), systemImage: "scalemass")
            case .byQuality: Label(String(localized: "Quality", comment: "Release filter"), systemImage: "slider.horizontal.3")
            case .bySeeders: Label(String(localized: "Seeders", comment: "Release filter"), systemImage: "person.wave.2")
            case .byFilesize: Label(String(localized: "File Size", comment: "Release filter"), systemImage: "internaldrive")
            case .byAge: Label(String(localized: "Age", comment: "Release filter"), systemImage: "calendar")
            case .byCustomScore: Label(String(localized: "Custom Score", comment: "Release filter"), systemImage: "person.badge.plus")
            }
        }

        func isOrderedBefore(_ lhs: MovieRelease, _ rhs: MovieRelease) -> Bool {
            switch self {
            case .byWeight:
                lhs.releaseWeight > rhs.releaseWeight
            case .bySeeders:
                lhs.seeders ?? 0 > rhs.seeders ?? 0
            case .byAge:
                lhs.ageMinutes > rhs.ageMinutes
            case .byFilesize:
                lhs.size > rhs.size
            case .byQuality:
                lhs.quality.quality.resolution > rhs.quality.quality.resolution
            case .byCustomScore:
                lhs.customFormatScore > rhs.customFormatScore
            }
        }
    }

    var hasFilter: Bool {
        type != ".all"
        || indexer != ".all"
        || quality != ".all"
        || language != ".all"
        || customFormat != ".all"
        || approved
        || freeleech
        || originalLanguage
    }

    mutating func resetFilters() {
        type = ".all"
        indexer = ".all"
        quality = ".all"
        language = ".all"
        customFormat = ".all"
        approved = false
        freeleech = false
        originalLanguage = false
    }
}

extension MovieReleaseSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(MovieReleaseSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "movie.releases.sort", message: "init failed", data: ["error": error])

            return nil
        }
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return result
    }
}

 extension MovieReleaseSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option

        case indexer
        case quality
        case language
        case type
        case customFormat

        case approved
        case freeleech
        case originalLanguage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            indexer: container.decode(String.self, forKey: .indexer),
            quality: container.decode(String.self, forKey: .quality),
            language: container.decode(String.self, forKey: .language),
            type: container.decode(String.self, forKey: .type),
            customFormat: container.decode(String.self, forKey: .customFormat),
            approved: container.decode(Bool.self, forKey: .approved),
            freeleech: container.decode(Bool.self, forKey: .freeleech),
            originalLanguage: container.decode(Bool.self, forKey: .originalLanguage)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(indexer, forKey: .indexer)
        try container.encode(quality, forKey: .quality)
        try container.encode(language, forKey: .language)
        try container.encode(type, forKey: .type)
        try container.encode(customFormat, forKey: .customFormat)
        try container.encode(approved, forKey: .approved)
        try container.encode(freeleech, forKey: .freeleech)
        try container.encode(originalLanguage, forKey: .originalLanguage)
    }
 }
