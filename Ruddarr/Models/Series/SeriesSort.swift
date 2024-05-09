import SwiftUI

struct SeriesSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byYear
        case byAiring
        case byAdded
        case bySize

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byYear: Label("Year", systemImage: "calendar")
            case .byAiring: Label("Next Airing", systemImage: "clock")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
            case .bySize: Label("File Size", systemImage: "internaldrive")
            }
        }

        func isOrderedBefore(_ lhs: Series, _ rhs: Series) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle > rhs.sortTitle
            case .byYear:
                lhs.sortYear < rhs.sortYear
            case .byAiring:
                lhs.nextAiring?.timeIntervalSince1970 ?? 0 < rhs.nextAiring?.timeIntervalSince1970 ?? 0
            case .byAdded:
                lhs.added < rhs.added
            case .bySize:
                lhs.statistics?.sizeOnDisk ?? 0 < rhs.statistics?.sizeOnDisk ?? 0
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

        func filtered(_ series: [Series]) -> [Series] {
            switch self {
            case .all:
                series
            case .monitored:
                series.filter { $0.monitored }
            case .unmonitored:
                series.filter { !$0.monitored }
            case .continuing:
                series.filter { $0.status == .continuing }
            case .ended:
                series.filter { $0.status == .ended }
            case .missing:
                series.filter { $0.episodeCount > $0.episodeFileCount }
            case .dangling:
                series.filter { !$0.monitored && $0.episodeCount == 0 }
            }
        }
    }
}

extension SeriesSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8)
            else { return nil }
            let result = try JSONDecoder().decode(SeriesSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "series.sort", message: "init failed", data: ["error": error])

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
