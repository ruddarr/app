import SwiftUI

struct SeriesReleaseSort: Equatable {
    var isAscending: Bool = true
    var option: Option = .byWeight

    var indexer: String = ".all"
    var quality: String = ".all"
    var language: String = ".all"
    var type: String = ".all"
    var customFormat: String = ".all"
    var seasonPack: SeasonPack = .any

    var approved: Bool = false
    var freeleech: Bool = false
    var originalLanguage: Bool = false

    enum Option: Hashable, Identifiable, CaseIterable {
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

        func isOrderedBefore(_ lhs: SeriesRelease, _ rhs: SeriesRelease) -> Bool {
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
                lhs.customFormatScore ?? 0 > rhs.customFormatScore ?? 0
            }
        }
    }

    enum SeasonPack: Identifiable, CaseIterable {
        var id: Self { self }

        case any
        case season
        case episode

        var label: String {
            switch self {
            case .any: String(localized: "Any")
            case .season: String(localized: "Season Pack")
            case .episode: String(localized: "Single Episode")
            }
        }

        var icon: String {
            switch self {
            case .any: "square.stack.3d.up"
            case .season: "shippingbox"
            case .episode: "numbersign"
            }
        }
    }

    var hasFilter: Bool {
        type != ".all"
        || indexer != ".all"
        || quality != ".all"
        || language != ".all"
        || customFormat != ".all"
        || seasonPack != .any
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
        seasonPack = .any
        approved = false
        freeleech = false
        originalLanguage = false
    }
}
