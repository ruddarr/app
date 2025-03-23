import SwiftUI

struct Episode: Identifiable, Codable, Equatable {
    let id: Int

    // used by deeplinks to switch instances
    var instanceId: Instance.ID?

    let seriesId: Int
    let episodeFileId: Int
    let tvdbId: Int

    let seasonNumber: Int
    let episodeNumber: Int
    let runtime: Int?

    let title: String?
    let overview: String?

    let hasFile: Bool
    var monitored: Bool
    let grabbed: Bool?

    let finaleType: EpisodeFinale?

    let airDateUtc: Date?

    let endTime: Date?
    let grabDate: Date?

    let absoluteEpisodeNumber: Int?
    let sceneAbsoluteEpisodeNumber: Int?
    let sceneEpisodeNumber: Int?
    let sceneSeasonNumber: Int?
    let unverifiedSceneNumbering: Bool

    let series: Series?

    var titleLabel: String {
        title ?? String(localized: "TBA")
    }

    var episodeLabel: String {
        String(format: "%dx%02d", seasonNumber, episodeNumber)
    }

    var statusLabel: String {
        if hasFile {
            return String(localized: "Downloaded", comment: "Episode status label")
        }

        if !hasAired {
            return String(localized: "Unaired", comment: "Episode status label")
        }

        return String(localized: "Missing", comment: "Episode status label")
    }

    var runtimeLabel: String? {
        guard let minutes = runtime, minutes > 0 else { return nil }
        return formatRuntime(minutes)
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
        hasFile
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

        if calendar.isDateInToday(date) { return RelativeDate.today.label }
        if calendar.isDateInTomorrow(date) { return RelativeDate.tomorrow.label }
        if calendar.isDateInYesterday(date) { return RelativeDate.yesterday.label }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var airDateTimeLabel: String {
        guard let date = airDateUtc else {
            return String(localized: "TBA")
        }

        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)

        if calendar.isDateInToday(date) {
            return String(localized: "\(RelativeDate.today.label) at \(time)", comment: "(Today/Tomorrow/Yesterday) at (time)")
        }

        if calendar.isDateInTomorrow(date) {
            return String(localized: "\(RelativeDate.tomorrow.label) at \(time)", comment: "(Today/Tomorrow/Yesterday) at (time)")
        }

        if calendar.isDateInYesterday(date) {
            return String(localized: "\(RelativeDate.yesterday.label) at \(time)", comment: "(Today/Tomorrow/Yesterday) at (time)")
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var airDateTimeShortLabel: String {
        guard let date = airDateUtc else { return String(localized: "TBA") }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        let weekday = date.formatted(.dateTime.weekday(.wide))

        if calendar.isDateInToday(date) { return String(localized: "\(RelativeDate.today.label) at \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "\(RelativeDate.tomorrow.label) at \(time)") }

        guard let days = calendar.dateComponents([.day], from: Date.now, to: date).day else {
            return airDateTimeLabel
        }

        return days < 7
            ? String(localized: "\(weekday) at \(time)")
            : date.formatted(date: .abbreviated, time: .shortened)
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

enum EpisodeReleaseType: String, Equatable, Codable {
    case unknown // 0
    case singleEpisode // 1
    case multiEpisode // 2
    case seasonPack // 3

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        do {
            let stringType = try container.decode(String.self)
            self = EpisodeReleaseType(rawValue: stringType) ?? .unknown
        } catch {
            // integer fallback (Sonarr v4.0.3)
            // https://github.com/Sonarr/Sonarr/pull/6707
            self = .unknown
        }
    }
}

extension Episode {
    static var void: Self {
        .init(
            id: 0, seriesId: 0, episodeFileId: 0, tvdbId: 0, seasonNumber: 0, episodeNumber: 0, runtime: 0, title: nil, overview: nil,
            hasFile: false, monitored: false, grabbed: false, finaleType: nil, airDateUtc: nil, endTime: nil, grabDate: nil, absoluteEpisodeNumber: nil,
            sceneAbsoluteEpisodeNumber: nil, sceneEpisodeNumber: nil, sceneSeasonNumber: nil, unverifiedSceneNumbering: false, series: nil
        )
    }
}
