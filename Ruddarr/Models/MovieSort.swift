import Foundation

struct MovieSort {
    var isAscending: Bool = false

    var option: Option = .byAdded
    var filter: Filter = .all

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

    enum Filter: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case all
        case monitored
        case unmonitored
        case missing
        case wanted
        case dangling

        var title: String {
            switch self {
            case .all: "All"
            case .monitored: "Monitored"
            case .unmonitored: "Unmonitored"
            case .missing: "Missing"
            case .wanted: "Wanted"
            case .dangling: "Dangling"
            }
        }

        func filtered(_ movies: [Movie]) -> [Movie] {
            switch self {
            case .all:
                movies
            case .monitored:
                movies.filter { $0.monitored }
            case .unmonitored:
                movies.filter { !$0.monitored }
            case .missing:
                movies.filter { $0.monitored && !$0.hasFile }
            case .wanted:
                movies.filter { $0.monitored && !$0.hasFile && $0.isAvailable }
            case .dangling:
                movies.filter { !$0.monitored && !$0.hasFile }
            }
        }
    }
}
