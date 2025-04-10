import SwiftUI

struct MovieSort: Equatable, Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byYear
        case byAdded
        case byRating
        case byGrabbed
        case bySize
        case byRelease

        var label: some View {
            switch self {
            case .byTitle: Label(String(localized: "Title", comment: "Media grid sorting"), systemImage: "textformat.abc")
            case .byYear: Label(String(localized: "Year", comment: "Media grid sorting"), systemImage: "calendar")
            case .byAdded: Label(String(localized: "Added", comment: "Media grid sorting"), systemImage: "calendar.badge.plus")
            case .byRating: Label(String(localized: "Rating", comment: "Media grid sorting"), systemImage: "star")
            case .byGrabbed: Label(String(localized: "Grabbed", comment: "Media grid sorting"), systemImage: "arrow.down.circle")
            case .bySize: Label(String(localized: "File Size", comment: "Media grid sorting"), systemImage: "internaldrive")
            case .byRelease: Label(String(localized: "Digital Release", comment: "Media grid sorting"), systemImage: "play.tv")
            }
        }

        func compare(_ lhs: Movie, _ rhs: Movie) -> Bool {
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
            case .byRating:
                lhs.ratingScore < rhs.ratingScore
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
            case .all: Label(String(localized: "All Movies", comment: "Media grid filter"), systemImage: "rectangle.stack")
            case .monitored: Label(String(localized: "Monitored", comment: "Media grid filter"), systemImage: "bookmark.fill")
            case .unmonitored: Label(String(localized: "Unmonitored", comment: "Media grid filter"), systemImage: "bookmark")
            case .missing: Label(String(localized: "Missing", comment: "Media grid filter"), systemImage: "exclamationmark.magnifyingglass")
            case .wanted: Label(String(localized: "Wanted", comment: "Media grid filter"), systemImage: "sparkle.magnifyingglass")
            case .downloaded: Label(String(localized: "Downloaded", comment: "Media grid filter"), systemImage: "internaldrive")
            case .dangling: Label(String(localized: "Dangling", comment: "Media grid filter"), systemImage: "questionmark.square")
            }
        }

        func filter(_ movie: Movie) -> Bool {
            switch self {
            case .all:
                true
            case .monitored:
                movie.monitored
            case .unmonitored:
                !movie.monitored
            case .missing:
                movie.monitored && !movie.isDownloaded && movie.isAvailable
            case .wanted:
                movie.monitored && !movie.isDownloaded
            case .downloaded:
                movie.isDownloaded
            case .dangling:
                !movie.monitored && !movie.isDownloaded
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

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
    }
}
