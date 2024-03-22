import Foundation

struct Episode: Identifiable, Codable {
    let id: Int

    let seriesId: Int
    let tvdbId: Int

    let seasonNumber: Int
    let episodeNumber: Int
    let runtime: Int

    let title: String?
    let seriesTitle: String?
    let overview: String?

    let hasFile: Bool
    let monitored: Bool
    let grabbed: Bool

    let finaleType: EpisodeFinale?

    let airDate: String? // "2024-03-10"
    let airDateUtc: Date?

    let endTime: Date?
    let grabDate: Date?

    // let episodeFileId: Int
    let absoluteEpisodeNumber: Int?
    let sceneAbsoluteEpisodeNumber: Int?
    let sceneEpisodeNumber: Int?
    let sceneSeasonNumber: Int?
    let unverifiedSceneNumbering: Bool

    var episodeLabel: String {
        String(format: "%02dx%02d", seasonNumber, episodeNumber)
    }

    var premiereLabel: String {
        seasonNumber == 1
            ? String(localized: "Series Premiere")
            : String(localized: "Season Premiere")
    }

    var specialLabel: String {
        String(localized: "Special")
    }

    var isSpecial: Bool {
        episodeNumber == 0 || seasonNumber == 0
    }

    var isPremiere: Bool {
        episodeNumber == 1 && seasonNumber > 0
    }

    var isDownloaded: Bool {
        hasFile || grabbed
    }
    var isWaiting: Bool {
        guard let date = airDateUtc else {
            return false
        }
        return date > Date.now
    }
}

enum EpisodeFinale: String, Codable {
    case series
    case season
    case midseason

    var label: String {
        switch self {
        case .series: String(localized: "Series Finale")
        case .season: String(localized: "Season Finale")
        case .midseason: String(localized: "Midseason Finale")
        }
    }
}
