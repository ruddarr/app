import SwiftUI

@Observable
class MovieMetadata {
    private var movieId: Movie.ID?

    var instance: Instance

    var files: [MovieFile] = []
    var extraFiles: [MovieExtraFile] = []
    var history: [MovieHistoryEvent] = []

    var filesLoading: Bool = false
    var filesError: Bool = false

    var historyLoading: Bool = false
    var historyError: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func setMovie(_ movie: Movie) {
        guard movieId == movie.id else {
            return
        }

        files = []
        extraFiles = []
        filesLoading = false

        history = []
        historyLoading = false
    }

    func fetchFiles(for movie: Movie) async {
        if movieId == movie.id && !files.isEmpty {
            return
        }

        filesLoading = true
        filesError = false

        do {
            files = try await dependencies.api.getMovieFiles(movie.id, instance)
            extraFiles = try await dependencies.api.getMovieExtraFiles(movie.id, instance)
        } catch {
            filesError = true
        }

        filesLoading = false
    }

    func fetchHistory(for movie: Movie) async {
        if movieId == movie.id && !history.isEmpty {
            return
        }

        historyLoading = true
        historyError = false

        do {
            history = try await dependencies.api.getMovieHistory(movie.id, instance)
        } catch {
            historyError = true
        }

        historyLoading = false
    }

    func refresh(for movie: Movie) async {
        do {
            files = try await dependencies.api.getMovieFiles(movie.id, instance)
            extraFiles = try await dependencies.api.getMovieExtraFiles(movie.id, instance)
        } catch {
            filesError = true
        }

        filesLoading = false

        do {
            history = try await dependencies.api.getMovieHistory(movie.id, instance)
        } catch {
            historyError = true
        }

        historyLoading = false
    }
}

struct MovieExtraFile: Identifiable, Codable {
    let id: Int
    let type: MovieExtraFileType
    let relativePath: String?

    enum MovieExtraFileType: String, Codable {
        case subtitle
        case metadata
        case other

        var label: LocalizedStringKey {
            switch self {
            case .subtitle: "Subtitles"
            case .metadata: "Metadata"
            case .other: "Other"
            }
        }
    }
}

struct MovieHistoryEvent: Identifiable, Codable {
    let id: Int
    let eventType: MovieHistoryEventType
    let date: Date

    let sourceTitle: String?

    let customFormats: [MovieCustomFormat]
    let customFormatScore: Int
    let quality: MovieQualityInfo
    let languages: [MovieLanguage]

    let data: [String: String?]?

    var languageLabel: String {
        languageSingleLabel(languages)
    }

    var scoreLabel: String? {
        guard !customFormats.isEmpty else { return nil }
        return formatCustomScore(customFormatScore)
    }

    var indexerLabel: String {
        guard let indexer = data("indexer"), !indexer.isEmpty else {
            return String(localized: "indexer", comment: "Fallback for indexer name within mid-sentence")
        }

        guard indexer.hasSuffix(" (Prowlarr)") else {
            return indexer
        }

        return String(indexer.dropLast(11))
    }

    var indexerFlagsLabel: String? {
        guard let flags = data("indexerFlags"), !flags.isEmpty, flags != "0" else {
            return nil
        }

        return flags.replacing("G_", with: "")
    }

    var downloadClientLabel: String {
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
            String(format: String(localized: "Movie grabbed from %1$@ and sent to %2$@."), indexerLabel, downloadClientLabel)
        case .downloadFolderImported:
            String(format: String(localized: "Movie downloaded successfully and imported from %@."), downloadClientLabel)
        case .downloadFailed:
            data("message") ?? fallback
        case .downloadIgnored:
            data("message") ?? fallback
        case .movieFileDeleted:
            switch data?["reason"] {
            case "Manual":
                String(localized: "File was deleted manually.")
            case "MissingFromDisk":
                String(localized: "File was not found on disk so it was unlinked from the movie in the database.")
            case "Upgrade":
                String(localized: "File was deleted to import an upgrade.")
            default:
                fallback
            }
        case .movieFolderImported:
            String(localized: "Movie imported from folder.")
        case .movieFileRenamed:
            String(localized: "Movie file was renamed.")
        }
    }

    func data(_ key: String) -> String? {
        guard let dict = data else { return nil }
        guard let value = dict[key] else { return nil }

        if key == "releaseSource" { return localizeReleaseSource(value) }
        if key == "movieMatchType" { return localizeMovieMatchType(value) }

        return value
    }
}

enum MovieHistoryEventType: String, Codable {
    case unknown
    case grabbed
    case downloadFolderImported
    case downloadFailed
    case downloadIgnored
    case movieFileDeleted
    case movieFolderImported // unused
    case movieFileRenamed

    var label: LocalizedStringKey {
        switch self {
        case .unknown: "Unknown"
        case .grabbed: "Grabbed"
        case .downloadFolderImported: "Imported"
        case .downloadFailed: "Failed"
        case .downloadIgnored: "Ignored"
        case .movieFileDeleted: "Deleted"
        case .movieFolderImported: "Imported" // unused
        case .movieFileRenamed: "Renamed"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .unknown: "Unknown Event"
        case .grabbed: "Grabbed"
        case .downloadFolderImported: "Movie Imported"
        case .downloadFailed: "Download Failed"
        case .downloadIgnored: "Download Ignored"
        case .movieFileDeleted: "Movie Deleted"
        case .movieFolderImported: "Folder Imported" // unused
        case .movieFileRenamed: "Movie Renamed"
        }
    }
}

func localizeReleaseSource(_ value: String?) -> String? {
    if value == "Rss" { return String(localized: "RSS") }
    if value == "Search" { return String(localized: "Search") }
    if value == "UserInvokedSearch" { return String(localized: "User Invoked Search") }
    if value == "InteractiveSearch" { return String(localized: "Interactive Search") }
    if value == "ReleasePush" { return String(localized: "Release Push") }

    return String(localized: "Unknown")
}

func localizeMovieMatchType(_ value: String?) -> String? {
    if value == "Title" { return String(localized: "Title") }
    if value == "Alias" { return String(localized: "Alias") }
    if value == "Id" { return String(localized: "Identifier") }

    return String(localized: "Unknown")
}
