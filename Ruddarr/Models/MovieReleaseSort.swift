import SwiftUI

struct MovieReleaseSort {
    var isAscending: Bool = false
    var option: Option = .byWeight

    var indexer: String = ".all"
    var quality: String = ".all"

    var approvedOnly: Bool = false
    var freeleechOnly: Bool = false

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byWeight
        case byAge
        case bySize
        case bySeeders

        var label: some View {
            switch self {
            case .byWeight: Label("Weight", systemImage: "scalemass")
            case .bySeeders: Label("Seeders", systemImage: "person.2.wave.2")
            case .bySize: Label("Size", systemImage: "externaldrive")
            case .byAge: Label("Age", systemImage: "calendar")
            }
        }

        func isOrderedBefore(_ lhs: MovieRelease, _ rhs: MovieRelease) -> Bool {
            switch self {
            case .byWeight:
                lhs.releaseWeight > rhs.releaseWeight
            case .bySeeders:
                lhs.seeders ?? 0 < rhs.seeders ?? 0
            case .byAge:
                lhs.ageMinutes < rhs.ageMinutes
            case .bySize:
                lhs.size < rhs.size
            }
        }
    }
}
