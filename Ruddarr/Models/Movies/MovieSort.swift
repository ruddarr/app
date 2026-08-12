import SwiftUI
import Sentry

struct MovieSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all
    var folder: String = .all

    static func == (lhs: MovieSort, rhs: MovieSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.filter == rhs.filter &&
        lhs.folder == rhs.folder
    }

    func filter(_ movie: Movie) -> Bool {
        if folder != .all && movie.rootFolderPath?.untrailingSlashIt != folder.untrailingSlashIt {
            return false
        }

        return switch filter {
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

        func sortKey(_ movie: Movie) -> Double {
            switch self {
            case .byTitle: 0
            case .byYear: movie.sortYear
            case .bySize: Double(movie.sizeOnDisk ?? 0)
            case .byAdded: movie.added.timeIntervalSince1970
            case .byGrabbed: (movie.movieFile?.dateAdded ?? .distantPast).timeIntervalSince1970
            case .byRelease: (movie.digitalRelease ?? .distantPast).timeIntervalSince1970
            case .byRating: Double(movie.ratingScore)
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
    }
}

extension MovieSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(MovieSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.warning, category: "movie.sort", message: "JSON decode failed: \(error)", data: ["error": error, "rawValue": rawValue])

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
        case folder
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter),
            folder: container.decodeIfPresent(String.self, forKey: .folder) ?? .all
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
        try container.encode(folder, forKey: .folder)
    }
}
