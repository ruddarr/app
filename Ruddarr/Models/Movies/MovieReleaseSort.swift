import SwiftUI

struct MovieReleaseSort: Equatable {
    var isAscending: Bool = true
    var option: Option = .byWeight

    var indexer: String = ".all"
    var quality: String = ".all"
    var language: String = ".all"
    var type: String = ".all"
    var customFormat: String = ".all"

    var approved: Bool = false
    var freeleech: Bool = false
    var originalLanguage: Bool = false

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byWeight
        case byAge
        case byQuality
        case bySeeders
        case byFilesize
        case byCustomScore

        var label: some View {
            switch self {
            case .byWeight: Label("Weight", systemImage: "scalemass")
            case .byQuality: Label("Quality", systemImage: "slider.horizontal.3")
            case .bySeeders: Label("Seeders", systemImage: "person.wave.2")
            case .byFilesize: Label("File Size", systemImage: "internaldrive")
            case .byAge: Label("Age", systemImage: "calendar")
            case .byCustomScore: Label("Custom Score", systemImage: "person.badge.plus")
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
