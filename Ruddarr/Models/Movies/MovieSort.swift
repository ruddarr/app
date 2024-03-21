import SwiftUI

struct MovieSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byYear
        case byAdded

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byYear: Label("Year", systemImage: "calendar")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
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

        var label: some View {
            switch self {
            case .all: Label("All Movies", systemImage: "rectangle.stack")
            case .monitored: Label("Monitored", systemImage: "bookmark.fill")
            case .unmonitored: Label("Unmonitored", systemImage: "bookmark")
            case .missing: Label("Missing", systemImage: "exclamationmark.magnifyingglass")
            case .wanted: Label("Wanted", systemImage: "sparkle.magnifyingglass")
            case .dangling: Label("Dangling", systemImage: "questionmark.square")
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
                movies.filter { $0.monitored && !$0.isDownloaded }
            case .wanted:
                movies.filter { $0.monitored && !$0.isDownloaded && $0.isAvailable }
            case .dangling:
                movies.filter { !$0.monitored && !$0.isDownloaded }
            }
        }
    }
}
