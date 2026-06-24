import Foundation

enum ProwlarrSearchCategory: String, CaseIterable, Identifiable {
    case all
    case movies
    case tv
    case audio
    case audiobooks
    case books
    case pc
    case console
    case other

    var id: Self { self }

    var label: String {
        switch self {
        case .all: String(localized: "Any Category", comment: "Prowlarr category picker")
        case .movies: String(localized: "Movies", comment: "Prowlarr category picker")
        case .tv: String(localized: "TV", comment: "Prowlarr category picker")
        case .audio: String(localized: "Audio", comment: "Prowlarr category picker")
        case .audiobooks: String(localized: "Audiobooks", comment: "Prowlarr category picker")
        case .books: String(localized: "Books", comment: "Prowlarr category picker")
        case .pc: String(localized: "Software", comment: "Prowlarr category picker — Newznab PC category")
        case .console: String(localized: "Console", comment: "Prowlarr category picker")
        case .other: String(localized: "Other", comment: "Prowlarr category picker")
        }
    }

    // Newznab parent IDs (1000, 2000, …) include all their subcategories on most indexers,
    // so .audio (3000) already returns audiobooks. .audiobooks (3030) is the narrower subset.
    var categoryIds: [Int] {
        switch self {
        case .all: []
        case .movies: [2_000]
        case .tv: [5_000]
        case .audio: [3_000]
        case .audiobooks: [3_030]
        case .books: [7_000]
        case .pc: [4_000]
        case .console: [1_000]
        case .other: [8_000]
        }
    }
}
