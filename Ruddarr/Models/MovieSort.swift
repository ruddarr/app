import Foundation

struct MovieSort: Codable {
    var isAscending: Bool = true
    var option: Option = .byTitle

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }
        case byTitle
        case byYear
        case byAdded

        var title: String {
            switch self {
            case .byTitle: "Title"
            case .byYear: "Year"
            case .byAdded: "Added"
            }
        }

        func isOrderedBefore(_ lhs: Movie, _ rhs: Movie) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle < rhs.sortTitle
            case .byYear:
                lhs.year < rhs.year
            case .byAdded:
                lhs.added < rhs.added
            }
        }
    }
}

extension MovieSort: CodableAndRawRepresentable { }
