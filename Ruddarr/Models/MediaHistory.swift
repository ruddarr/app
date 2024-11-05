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

        return switch eventType {
        case .unknown:
            fallback
        case .grabbed:
            String(format: String(localized: "Movie grabbed from %1$@ and sent to %2$@."), indexerFallbackLabel, downloadClientFallbackLabel)
        case .downloadFolderImported:
            String(format: String(localized: "Movie downloaded successfully and imported from %@."), downloadClientFallbackLabel)
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
                String(
                    format: String(localized: "File was not found on disk so it was unlinked from the %@ in the database."),
                    eventType == .episodeFileDeleted
                        ? String(localized: "episode", comment: "The word 'episode' used mid-sentence")
                        : String(localized: "movie", comment: "The word 'movie' used mid-sentence")
                )
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

    var label: LocalizedStringKey {
        switch self {
        case .unknown: "Unknown"
        case .grabbed: "Grabbed"
        case .downloadFolderImported: "Imported"
        case .downloadFailed: "Failed"
        case .downloadIgnored: "Ignored"
        case .movieFileRenamed, .episodeFileRenamed: "Renamed"
        case .movieFileDeleted, .episodeFileDeleted: "Deleted"
        case .movieFolderImported, .seriesFolderImported: "Imported"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .unknown: "Unknown Event"
        case .grabbed: "Release Grabbed"
        case .downloadFolderImported: "Folder Imported"
        case .downloadFailed: "Download Failed"
        case .downloadIgnored: "Download Ignored"
        case .movieFileRenamed: "Movie Renamed"
        case .movieFileDeleted: "Movie Deleted"
        case .movieFolderImported: "Folder Imported"
        case .episodeFileRenamed: "Episode Renamed"
        case .episodeFileDeleted: "Episode Deleted"
        case .seriesFolderImported: "Folder Imported"
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
    if value == "Search" { return String(localized: "Search") }
    if value == "UserInvokedSearch" { return String(localized: "User Invoked Search") }
    if value == "InteractiveSearch" { return String(localized: "Interactive Search") }
    if value == "ReleasePush" { return String(localized: "Release Push") }

    return String(localized: "Unknown")
}

func localizeMatchType(_ value: String?) -> String? {
    if value == "Title" { return String(localized: "Title") }
    if value == "Alias" { return String(localized: "Alias") }
    if value == "Id" { return String(localized: "Identifier") }

    return String(localized: "Unknown")
}
