import Foundation

struct MovieReleaseSort {
    var isAscending: Bool = false
    var option: Option = .byWeight

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byWeight
        case byQuality
        case byAge
        case bySize

        var title: String {
            switch self {
            case .byWeight: "Weight"
            case .byQuality: "Quality"
            case .byAge: "Age"
            case .bySize: "Size"
            }
        }

        func isOrderedBefore(_ lhs: MovieRelease, _ rhs: MovieRelease) -> Bool {
            switch self {
            case .byWeight:
                lhs.releaseWeight > rhs.releaseWeight
            case .byQuality:
                lhs.qualityWeight > rhs.qualityWeight
            case .byAge:
                lhs.ageMinutes > rhs.ageMinutes
            case .bySize:
                lhs.size > rhs.size
            }
        }
    }
}
