import Foundation

@Observable
class Queue {
    static let shared = Queue()

    private var timer: Timer?

    var error: API.Error?

    var isLoading: Bool = false
    var performRefresh: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [QueueItem]] = [:]

    private init() {
        let interval: TimeInterval = isRunningIn(.simulator) ? 30 : 5

        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { await self.fetchTasks() }

            if self.performRefresh {
                Task { await self.refreshDownloadClients() }
            }
        }
    }

    var badgeCount: Int {
        items.flatMap { $0.value }.filter { $0.trackedDownloadStatus != .ok }.count
    }

    @MainActor
    func fetchTasks() async {
        guard !isLoading else { return }

        error = nil
        isLoading = true

        for instance in instances {
            do {
                items[instance.id] = try await dependencies.api.fetchQueueTasks(instance).records
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "queue", message: "Fetch failed", data: ["error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }
        }

        isLoading = false
    }

    func refreshDownloadClients() async {
        for instance in instances {
            do {
                _ = try await dependencies.api.command(.refreshDownloads, instance)
            } catch is CancellationError {
                // do nothing
            } catch {
                leaveBreadcrumb(.error, category: "queue", message: "Refresh failed", data: ["error": error])
            }
        }
    }
}

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

    let type: MediaReleaseType

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
    let trackedDownloadStatus: QueueDownloadStatus?
    let trackedDownloadState: QueueDownloadState?

    let outputPath: String?
    let downloadClientHasPostImportCategory: Bool?

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
        case trackedDownloadStatus
        case trackedDownloadState
        case outputPath
    }

    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.trackedDownloadStatus == rhs.trackedDownloadStatus &&
        lhs.trackedDownloadState == rhs.trackedDownloadState &&
        lhs.estimatedCompletionTime == rhs.estimatedCompletionTime
    }

    var isSABnzbd: Bool {
        downloadClient == "SABnzbd"
    }

    var isDownloadStation: Bool {
        downloadClient == "Download Station"
    }

    var messages: [QueueStatusMessage] {
        statusMessages ?? []
    }

    var titleLabel: String {
        if let title = movie?.title {
            return title
        }

        if let title = series?.title {
            guard let label = episode?.episodeLabel else { return title }
            return "\(title) \(label)"
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
            case "queued": String(localized: "Queued")
            case "paused": String(localized: "Paused")
            case "failed": String(localized: "Failed")
            case "downloading": String(localized: "Downloading")
            case "delay": String(localized: "Pending")
            case "downloadClientUnavailable": String(localized: "Pending")
            case "warning": String(localized: "Error")
            default: String(localized: "Unknown")
            }
        }

        return switch trackedDownloadState {
        case .importPending: String(localized: "Import Pending")
        case .importBlocked: String(localized: "Import Blocked")
        case .importing: String(localized: "Importing")
        case .failedPending: String(localized: "Waiting")
        default: String(localized: "Downloading")
        }
    }

    var extendedStatusLabel: String {
        if status == nil {
            return String(localized: "Unknown")
        }

        if status != "completed" {
            return switch status {
            case "queued": String(localized: "Queued")
            case "paused": String(localized: "Paused")
            case "failed": String(localized: "Download Failed")
            case "downloading": String(localized: "Downloading")
            case "delay": String(localized: "Pending")
            case "downloadClientUnavailable": String(localized: "Download Client Unavailable")
            case "warning": String(localized: "Download Client Warning")
            default: String(localized: "Unknown")
            }
        }

        return switch trackedDownloadState {
        case .importPending: String(localized: "Waiting to Import")
        case .importBlocked: String(localized: "Unable to Import Automatically")
        case .importing: String(localized: "Importing")
        case .failedPending: String(localized: "Waiting to Process")
        default: String(localized: "Downloading")
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
