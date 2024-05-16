import SwiftUI

struct Season: Identifiable, Equatable, Codable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    var monitored: Bool
    let statistics: SeasonStatistics?

    var label: String {
        seasonNumber == 0
            ? String(localized: "Specials")
            : String(localized: "Season \(seasonNumber)")
    }

    var progressLabel: String? {
        guard let stats = statistics else { return nil }
        return "\(stats.episodeFileCount) / \(stats.totalEpisodeCount)"
    }

    var episodeCountLabel: LocalizedStringKey {
        guard let stats = statistics else { return "Episodes" }
        return "\(stats.totalEpisodeCount) Episodes"
    }

    struct SeasonStatistics: Equatable, Codable {
        let episodeFileCount: Int
        let episodeCount: Int
        let totalEpisodeCount: Int
        let sizeOnDisk: Int
    }
}
