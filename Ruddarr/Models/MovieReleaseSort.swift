import Foundation

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

        var title: String {
            switch self {
            case .byWeight: "Weight"
            case .bySeeders: "Seeders"
            case .byAge: "Age"
            case .bySize: "Size"
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
