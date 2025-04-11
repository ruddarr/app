import SwiftUI

struct SeriesSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byYear
        case byAdded
        case byRating
        case bySize
        case byNextAiring
        case byPreviousAiring

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byYear: Label("Year", systemImage: "calendar")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
            case .byRating: Label("Rating", systemImage: "star")
            case .bySize: Label("File Size", systemImage: "internaldrive")
            case .byNextAiring: Label("Next Airing", systemImage: "clock")
            case .byPreviousAiring: Label("Previous Airing", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }
        }

        func compare(_ lhs: Series, _ rhs: Series) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle < rhs.sortTitle
            case .byYear:
                lhs.sortYear < rhs.sortYear
            case .byAdded:
                lhs.added < rhs.added
            case .bySize:
                lhs.statistics?.sizeOnDisk ?? 0 < rhs.statistics?.sizeOnDisk ?? 0
            case .byNextAiring:
                lhs.nextAiring ?? Date.distantFuture > rhs.nextAiring ?? Date.distantFuture
            case .byPreviousAiring:
                lhs.previousAiring ?? Date.distantPast < rhs.previousAiring ?? Date.distantPast
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
        case continuing
        case ended
        case missing
        case dangling

        var label: some View {
            switch self {
            case .all: Label("All TV Series", systemImage: "rectangle.stack")
            case .monitored: Label("Monitored", systemImage: "bookmark.fill")
            case .unmonitored: Label("Unmonitored", systemImage: "bookmark")
            case .continuing: Label("Continuing", systemImage: "play.fill")
            case .ended: Label("Ended", systemImage: "stop.fill")
            case .missing: Label("Missing", systemImage: "exclamationmark.magnifyingglass")
            case .dangling: Label("Dangling", systemImage: "questionmark.square")
            }
        }

        func filter(_ series: Series) -> Bool {
            switch self {
            case .all:
                true
            case .monitored:
                series.monitored
            case .unmonitored:
                !series.monitored
            case .continuing:
                series.status == .continuing
            case .ended:
                series.status == .ended
            case .missing:
                series.episodeCount > series.episodeFileCount
            case .dangling:
                !series.monitored && series.episodeCount == 0
            }
        }
    }
}

extension SeriesSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            let compat = rawValue.replacingOccurrences(of: "byAiring", with: "byNextAiring")
            guard let data = compat.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(SeriesSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "series.sort", message: "init failed", data: ["error": error, "rawValue": rawValue])

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

extension SeriesSort: Codable {
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
