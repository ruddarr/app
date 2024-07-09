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
        case byGrabbed
        case bySize
        case byRelease

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byYear: Label("Year", systemImage: "calendar")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
            case .byGrabbed: Label("Grabbed", systemImage: "arrow.down.circle")
            case .bySize: Label("File Size", systemImage: "internaldrive")
            case .byRelease: Label("Digital Release", systemImage: "play.tv")
            }
        }

        func isOrderedBefore(_ lhs: Movie, _ rhs: Movie) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle < rhs.sortTitle
            case .byYear:
                lhs.sortYear < rhs.sortYear
            case .bySize:
                lhs.sizeOnDisk ?? 0 < rhs.sizeOnDisk ?? 0
            case .byAdded:
                lhs.added < rhs.added
            case .byGrabbed:
                lhs.movieFile?.dateAdded ?? Date.distantPast < rhs.movieFile?.dateAdded ?? Date.distantPast
            case .byRelease:
                lhs.digitalRelease ?? Date.distantPast < rhs.digitalRelease ?? Date.distantPast
            }
        }
    }

    enum Filter: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case all
        case monitored
        case unmonitored
        case downloaded
        case wanted
        case missing
        case dangling

        var label: some View {
            switch self {
            case .all: Label("All Movies", systemImage: "rectangle.stack")
            case .monitored: Label("Monitored", systemImage: "bookmark.fill")
            case .unmonitored: Label("Unmonitored", systemImage: "bookmark")
            case .missing: Label("Missing", systemImage: "exclamationmark.magnifyingglass")
            case .wanted: Label("Wanted", systemImage: "sparkle.magnifyingglass")
            case .downloaded: Label("Downloaded", systemImage: "internaldrive")
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
                movies.filter { $0.monitored && !$0.isDownloaded && $0.isReleased }
            case .wanted:
                movies.filter { $0.monitored && !$0.isDownloaded }
            case .downloaded:
                movies.filter { $0.isDownloaded }
            case .dangling:
                movies.filter { !$0.monitored && !$0.isDownloaded }
            }
        }
    }
}

extension MovieSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(MovieSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "movie.sort", message: "init failed", data: ["error": error])

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

extension MovieSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case filter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
    }
}
