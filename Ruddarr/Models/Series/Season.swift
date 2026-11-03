import Foundation

struct Season: Identifiable, Equatable, Codable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    var monitored: Bool
    let title: String?
    let statistics: SeasonStatistics?

    var label: String {
        seasonNumber == 0
            ? String(localized: "Specials")
            : String(localized: "Season \(seasonNumber)")
    }

    var subtitle: String? {
        guard let title, !title.isEmpty, title.caseInsensitiveCompare(label) != .orderedSame else { return nil }
        return title
    }

    var progressLabel: String? {
        guard let stats = statistics else { return nil }
        return "\(stats.episodeFileCount) / \(stats.totalEpisodeCount)"
    }

    struct SeasonStatistics: Equatable, Codable {
        let episodeFileCount: Int
        let episodeCount: Int
        let totalEpisodeCount: Int
        let sizeOnDisk: Int
    }
}
