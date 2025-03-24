import SwiftUI

struct MediaHistory: Codable {
    let page: Int
    let pageSize: Int
    let totalRecords: Int

    var records: [MediaHistoryEvent]
}

struct MediaHistoryEvent: Identifiable, Codable {
    let id: Int
    let eventType: HistoryEventType
    let date: Date

    // used for filtering
    var instanceId: Instance.ID?

    let sourceTitle: String?

    // Radarr
    let movieId: Int?

    // Sonarr
    let seriesId: Int?
    let episodeId: Int?

    let quality: MediaQuality
    let languages: [MediaLanguage]?

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    let data: [String: String?]?

    var languageLabel: String {
        languageSingleLabel(languages ?? [])
    }

    var scoreLabel: String? {
        guard !(customFormats ?? []).isEmpty else { return nil }
        return formatCustomScore(customFormatScore ?? 0)
    }

    var indexerLabel: String? {
        guard let indexer = data("indexer"), !indexer.isEmpty else {
            return nil
        }

        return formatIndexer(indexer)
    }

    var indexerFlagsLabel: String? {
        guard let flags = data("indexerFlags"), !flags.isEmpty, flags != "0" else {
            return nil
        }

        return flags.replacing("G_", with: "")
    }

    var indexerFallbackLabel: String {
        guard let indexer = indexerLabel else {
            return String(localized: "indexer", comment: "Fallback for indexer name within mid-sentence")
        }

        return indexer
    }

    var downloadClientFallbackLabel: String {
        guard let client = data("downloadClient"), !client.isEmpty else {
            return String(localized: "download client", comment: "Fallback for download client name within mid-sentence")
        }

        return client
    }

    var description: String {
        let fallback = String(localized: "Unknown event.")

        let mediaNoun = movieId != nil
            ? String(localized: "Movie")
            : String(localized: "Episode")

        return switch eventType {
        case .unknown:
            fallback
        case .grabbed:
            String(format: String(
                localized: "%1$@ grabbed from %2$@ and sent to %3$@."),
                mediaNoun,
                indexerFallbackLabel,
                downloadClientFallbackLabel
            )
        case .downloadFolderImported:
            String(format: String(
                localized: "%1$@ downloaded successfully and imported from %2$@."),
                mediaNoun,
                downloadClientFallbackLabel
            )
        case .downloadFailed:
            data("message") ?? fallback
        case .downloadIgnored:
            data("message") ?? fallback
        case .movieFileRenamed:
            String(localized: "Movie file was renamed.")
        case .episodeFileRenamed:
            String(localized: "Episode file was renamed.")
        case .movieFileDeleted, .episodeFileDeleted:
            switch data?["reason"] {
            case "Manual":
                String(localized: "File was deleted either manually or by a client through the API.")
            case "MissingFromDisk":
                eventType == .episodeFileDeleted
                    ? String(localized: "File was not found on disk so it was unlinked from the episode in the database.")
                    : String(localized: "File was not found on disk so it was unlinked from the movie in the database.")
            case "Upgrade":
                String(localized: "File was deleted to import an upgrade.")
            default:
                fallback
            }
        case .movieFolderImported:
            String(localized: "Movie imported from folder.")
        case .seriesFolderImported:
            String(localized: "Series imported from folder.")
        }
    }

    func data(_ key: String) -> String? {
        guard let dict = data else { return nil }
        guard let value = dict[key] else { return nil }

        if ["movieMatchType", "seriesMatchType"].contains(key) {
            return localizeMatchType(value)
        }

        if key == "releaseType" {
            return localizeReleaseType(value)
        }

        if key == "releaseSource" {
            return localizeReleaseSource(value)
        }

        return value
    }
}

enum HistoryEventType: String, Codable {
    case unknown
    case grabbed
    case downloadFolderImported
    case downloadFailed
    case downloadIgnored

    case movieFileRenamed
    case movieFileDeleted
    case movieFolderImported // unused

    case episodeFileRenamed
    case episodeFileDeleted
    case seriesFolderImported

    var ref: String {
        switch self {
        case .unknown: ".unknown"
        case .grabbed: ".grabbed"
        case .downloadFolderImported, .movieFolderImported, .seriesFolderImported: ".imported"
        case .downloadFailed: ".failed"
        case .downloadIgnored: ".ignored"
        case .movieFileRenamed, .episodeFileRenamed: ".renamed"
        case .movieFileDeleted, .episodeFileDeleted: ".deleted"
        }
    }

    var label: String {
        switch self {
        case .unknown:
            String(localized: "Unknown", comment: "(Short) Title of history event")
        case .grabbed:
            String(localized: "Grabbed", comment: "(Short) Title of history event")
        case .downloadFolderImported:
            String(localized: "Imported", comment: "(Short) Title of history event")
        case .downloadFailed:
            String(localized: "Failed", comment: "(Short) Title of history event")
        case .downloadIgnored:
            String(localized: "Ignored", comment: "(Short) Title of history event")
        case .movieFileRenamed, .episodeFileRenamed:
            String(localized: "Renamed", comment: "(Short) Title of history event")
        case .movieFileDeleted, .episodeFileDeleted:
            String(localized: "Deleted", comment: "(Short) Title of history event")
        case .movieFolderImported, .seriesFolderImported:
            String(localized: "Imported", comment: "(Short) Title of history event")
        }
    }

    var title: String {
        switch self {
        case .unknown:
            String(localized: "Unknown Event", comment: "Title of history event type")
        case .grabbed:
            String(localized: "Release Grabbed", comment: "Title of history event type")
        case .downloadFolderImported:
            String(localized: "Folder Imported", comment: "Title of history event type")
        case .downloadFailed:
            String(localized: "Download Failed", comment: "Title of history event type")
        case .downloadIgnored:
            String(localized: "Download Ignored", comment: "Title of history event type")
        case .movieFileRenamed:
            String(localized: "Movie Renamed", comment: "Title of history event type")
        case .movieFileDeleted:
            String(localized: "Movie Deleted", comment: "Title of history event type")
        case .movieFolderImported:
            String(localized: "Folder Imported", comment: "Title of history event type")
        case .episodeFileRenamed:
            String(localized: "Episode Renamed", comment: "Title of history event type")
        case .episodeFileDeleted:
            String(localized: "Episode Deleted", comment: "Title of history event type")
        case .seriesFolderImported:
            String(localized: "Folder Imported", comment: "Title of history event type")
        }
    }
}

func localizeReleaseType(_ value: String?) -> String? {
    if value == "SingleEpisode" { return String(localized: "Single Episode") }
    if value == "MultiEpisode" { return String(localized: "Multi-Episode") }
    if value == "SeasonPack" { return String(localized: "Season Pack") }

    return String(localized: "Unknown")
}

func localizeReleaseSource(_ value: String?) -> String? {
    if value == "Rss" { return String("RSS") }
    if value == "Search" { return String(localized: "Search", comment: "Source of the release") }
    if value == "UserInvokedSearch" { return String(localized: "User Invoked Search", comment: "Source of the release") }
    if value == "InteractiveSearch" { return String(localized: "Interactive Search", comment: "Source of the release") }
    if value == "ReleasePush" { return String(localized: "Release Push", comment: "Source of the release") }

    return String(localized: "Unknown")
}

func localizeMatchType(_ value: String?) -> String? {
    if value == "Title" { return String(localized: "Title", comment: "Match type of the release") }
    if value == "Alias" { return String(localized: "Alias", comment: "Match type of the release") }
    if value == "Id" { return String(localized: "Identifier", comment: "Match type of the release") }

    return String(localized: "Unknown")
}
