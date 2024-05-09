import SwiftUI

struct Episode: Identifiable, Codable {
    let id: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let seriesId: Int
    let episodeFileId: Int
    let tvdbId: Int

    let seasonNumber: Int
    let episodeNumber: Int
    let runtime: Int

    let title: String?
    let seriesTitle: String?
    let overview: String?

    let hasFile: Bool
    var monitored: Bool
    let grabbed: Bool

    let finaleType: EpisodeFinale?

    // let airDate: String? // "2024-03-10"
    let airDateUtc: Date?

    let endTime: Date?
    let grabDate: Date?

    // let episodeFileId: Int
    let absoluteEpisodeNumber: Int?
    let sceneAbsoluteEpisodeNumber: Int?
    let sceneEpisodeNumber: Int?
    let sceneSeasonNumber: Int?
    let unverifiedSceneNumbering: Bool

    var titleLabel: String {
        title ?? String(localized: "TBA")
    }

    // TODO: Do we need anime formatting?
    var episodeLabel: String {
        String(format: "%dx%02d", seasonNumber, episodeNumber)
    }

    var statusLabel: LocalizedStringKey {
        if hasFile { return "Downloaded" }
        if !hasAired { return "Unaired" }
        return "Missing"
    }

    var runtimeLabel: String? {
        guard runtime > 0 else { return nil }
        return formatRuntime(runtime)
    }

    var premiereLabel: LocalizedStringKey {
        seasonNumber == 1 ? "Series Premiere" : "Season Premiere"
    }

    var specialLabel: LocalizedStringKey {
        "Special"
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

    var isMissing: Bool {
        hasAired && !hasFile
    }

    var hasAired: Bool {
        guard let date = airDateUtc else { return false }
        return date < Date.now
    }

    var airingToday: Bool {
        guard let date = airDateUtc else { return false }
        return Calendar.current.isDateInToday(date)
    }

    var airDateLabel: String {
        guard let date = airDateUtc else { return String(localized: "TBA") }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var airDateTimeLabel: String {
        guard let date = airDateUtc else { return String(localized: "TBA") }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return String(localized: "Today at \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow at \(time)") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday at \(time)") }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

enum EpisodeFinale: String, Codable {
    case series
    case season
    case midseason

    var label: LocalizedStringKey {
        switch self {
        case .series: "Series Finale"
        case .season: "Season Finale"
        case .midseason: "Midseason Finale"
        }
    }
}

struct EpisodesMonitorResource: Codable {
    let episodeIds: [Int]
    let monitored: Bool
}

extension Episode {
    static var void: Self {
        .init(
            id: 0, seriesId: 0, episodeFileId: 0, tvdbId: 0, seasonNumber: 0, episodeNumber: 0, runtime: 0, title: nil, seriesTitle: nil, overview: nil,
            hasFile: false, monitored: false, grabbed: false, finaleType: nil, airDateUtc: nil, endTime: nil, grabDate: nil, absoluteEpisodeNumber: nil,
            sceneAbsoluteEpisodeNumber: nil, sceneEpisodeNumber: nil, sceneSeasonNumber: nil, unverifiedSceneNumbering: false
        )
    }
}
