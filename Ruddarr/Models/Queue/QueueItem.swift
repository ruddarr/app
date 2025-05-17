import Foundation

struct QueueItems: Codable {
    let page: Int
    let pageSize: Int
    let totalRecords: Int

    var records: [QueueItem]
}

struct QueueItem: Codable, Identifiable, Equatable {
    let id: Int

    // used for filtering
    var instanceId: Instance.ID?

    let downloadId: String?
    let downloadClient: String?

    // Radarr
    let movieId: Int?
    let movie: Movie?

    // Sonarr
    let seriesId: Int?
    let series: Series?
    let episodeId: Int?
    let episode: Episode?
    let episodeHasFile: Bool?
    let seasonNumber: Int?

    let title: String?
    let indexer: String?

    let type: ReleaseProtocol

    let size: Float
    let sizeleft: Float
    let timeleft: String?

    let languages: [MediaLanguage]?
    let quality: MediaQuality

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    let added: Date?
    var estimatedCompletionTime: Date?

    let status: String?
    let statusMessages: [QueueStatusMessage]?
    let errorMessage: String?

    let trackedDownloadStatus: QueueDownloadStatus?
    let trackedDownloadState: QueueDownloadState?

    let outputPath: String?
    let downloadClientHasPostImportCategory: Bool?

    var taskGroupCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case downloadId
        case downloadClient
        case movieId
        case movie
        case seriesId
        case series
        case episodeId
        case episode
        case episodeHasFile
        case seasonNumber
        case title
        case indexer
        case type = "protocol"
        case size
        case sizeleft
        case timeleft
        case languages
        case quality
        case customFormats
        case customFormatScore
        case added
        case estimatedCompletionTime
        case downloadClientHasPostImportCategory
        case status
        case statusMessages
        case errorMessage
        case trackedDownloadStatus
        case trackedDownloadState
        case outputPath
    }

    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.instanceId == rhs.instanceId &&
        lhs.status == rhs.status &&
        lhs.size == rhs.size &&
        lhs.sizeleft == rhs.sizeleft &&
        lhs.trackedDownloadStatus == rhs.trackedDownloadStatus &&
        lhs.trackedDownloadState == rhs.trackedDownloadState &&
        lhs.estimatedCompletionTime == rhs.estimatedCompletionTime
    }

    var hasIssue: Bool {
        trackedDownloadStatus != .ok ||
        status == "warning"
    }

    var needsManualImport: Bool {
        downloadId != nil &&
        trackedDownloadStatus == .warning &&
        [.importPending, .importBlocked].contains(trackedDownloadState)
    }

    var isSABnzbd: Bool {
        downloadId?.contains("SABnzbd_") == true ||
        downloadClient?.localizedCaseInsensitiveContains("SABnzbd") == true
    }

    var isDownloadStation: Bool {
        downloadId?.contains(":dbid_") == true ||
        downloadClient?.localizedCaseInsensitiveContains("Download Station") == true
    }

    var messages: [QueueStatusMessage] {
        statusMessages ?? []
    }

    var taskGroup: String {
        (downloadId ?? "") + (title ?? "") + String(seasonNumber ?? id) + String(size)
    }

    var titleLabel: String {
        if let title = movie?.title {
            return title
        }

        if let title = series?.title {
            if let count = taskGroupCount, count > 1 {
                return String(format: "%@ (%@)", title, String(localized: "Season \(1)"))
            }

            guard let episodeLabel = episode?.episodeLabel else {
                return title
            }

            return "\(title) \(episodeLabel)"
        }

        return title ?? String(localized: "Unknown")
    }

    var progressLabel: String {
        guard sizeleft > 0 else { return 100.formatted(.percent) }
        return ((size - sizeleft) / size).formatted(.percent.precision(.fractionLength(1)))
    }

    var remainingLabel: String? {
        guard trackedDownloadState == .downloading else { return nil }
        guard let time = estimatedCompletionTime else { return nil }
        guard time > Date.now else { return nil }
        return formatRemainingTime(time)
    }

    var languagesLabel: String {
        guard let codes = languages, !codes.isEmpty else {
            return String(localized: "Unknown")
        }

        return codes.map { $0.label }.formattedList()
    }

    var scoreLabel: String? {
        guard let score = customFormatScore else { return nil }
        guard let formats = customFormats, !formats.isEmpty else { return nil }
        return formatCustomScore(score)
    }

    var customFormatsLabel: String? {
        guard let formats = customFormats, !formats.isEmpty else { return nil }
        return formats.map { $0.label }.formattedList()
    }

    var statusLabel: String {
        if status == nil {
            return String(localized: "Unknown")
        }

        if status != "completed" {
            return switch status {
            case "queued": String(localized: "Queued", comment: "(Short) State of task in queue")
            case "paused": String(localized: "Paused", comment: "(Short) State of task in queue")
            case "failed": String(localized: "Failed", comment: "(Short) State of task in queue")
            case "downloading": String(localized: "Downloading", comment: "(Short) State of task in queue")
            case "delay": String(localized: "Pending", comment: "(Short) State of task in queue")
            case "downloadClientUnavailable": String(localized: "Pending", comment: "(Short) State of task in queue")
            case "warning": String(localized: "Warning", comment: "(Short) State of task in queue")
            default: String(localized: "Unknown", comment: "(Short) State of task in queue")
            }
        }

        return switch trackedDownloadState {
        case .importPending: String(localized: "Import Pending", comment: "(Short) State of task in queue")
        case .importBlocked: String(localized: "Import Blocked", comment: "(Short) State of task in queue")
        case .importing: String(localized: "Importing", comment: "(Short) State of task in queue")
        case .failedPending: String(localized: "Waiting", comment: "(Short) State of task in queue")
        default: String(localized: "Downloading", comment: "(Short) State of task in queue")
        }
    }

    var extendedStatusLabel: String {
        if status == nil {
            return String(localized: "Unknown")
        }

        if status != "completed" {
            return switch status {
            case "queued": String(localized: "Queued", comment: "Status of task in queue")
            case "paused": String(localized: "Paused", comment: "Status of task in queue")
            case "failed": String(localized: "Download Failed", comment: "Status of task in queue")
            case "downloading": String(localized: "Downloading", comment: "Status of task in queue")
            case "delay": String(localized: "Pending", comment: "Status of task in queue")
            case "downloadClientUnavailable": String(localized: "Download Client Unavailable", comment: "Status of task in queue")
            case "warning": String(localized: "Download Client Warning", comment: "Status of task in queue")
            default: String(localized: "Unknown", comment: "Status of task in queue")
            }
        }

        return switch trackedDownloadState {
        case .importPending: String(localized: "Waiting to Import", comment: "State of task in queue")
        case .importBlocked: String(localized: "Unable to Import Automatically", comment: "State of task in queue")
        case .importing: String(localized: "Importing", comment: "State of task in queue")
        case .failedPending: String(localized: "Waiting to Process", comment: "State of task in queue")
        default: String(localized: "Downloading", comment: "State of task in queue")
        }
    }
}

struct QueueStatusMessage: Codable, Hashable {
    let title: String?
    let messages: [String]
}

enum QueueDownloadStatus: String, Codable {
    case ok
    case warning
    case error
}

enum QueueDownloadState: String, Codable {
    case downloading
    case importPending
    case importBlocked // https://github.com/Sonarr/Sonarr/pull/6889
    case importing
    case imported
    case failedPending
    case failed
    case ignored
}
