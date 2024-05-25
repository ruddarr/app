import Foundation

@Observable
class Queue {
    static let shared = Queue()

    private var timer: Timer?

    var error: API.Error?
    var isLoading: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [QueueItem]] = [:]

    private init() {
        // TODO: show bubble, if download is active or pending?

        self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task {
                await self.fetch()
            }
        }
    }

    var badgeCount: Int {
        return 0
        // items.filter
    }

    func fetch() async {
        guard !isLoading else { return }

        error = nil
        isLoading = true

        for instance in instances {
            do {
                items[instance.id] = try await dependencies.api.queue(instance).records
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "calendar", message: "Request failed", data: ["error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }
        }

        isLoading = false
    }
}

struct QueueItems: Codable {
    let page: Int
    let pageSize: Int
    let totalRecords: Int

    let records: [QueueItem]
}

struct QueueItem: Codable, Identifiable {
    let id: Int

    let downloadId: String?
    let downloadClient: String?

    let movieId: Int

    let title: String?
    let indexer: String?

    let type: MediaReleaseType

    let size: Float
    let sizeleft: Float
    let timeleft: String?

    let languages: [MediaLanguage]
    let quality: MediaQuality

    let customFormats: [MediaCustomFormat]
    let customFormatScore: Int

    let added: Date?
    let estimatedCompletionTime: Date?

    let downloadClientHasPostImportCategory: Bool

    let status: String?
    let statusMessages: [QueueStatusMessage]
    let trackedDownloadStatus: QueueDownloadStatus
    let trackedDownloadState: QueueDownloadState

    let outputPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case downloadId
        case downloadClient
        case movieId
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

    var progressLabel: String {
        ((size - sizeleft) / size).formatted(
            .percent.precision(.fractionLength(1))
        )
    }

    var statusLabel: String {
        if status == nil {
            return String(localized: "Unknown")
        }

        if status != "completed" {
            return switch status {
            case "queue": String(localized: "Queue")
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
        case .importPending: String(localized: "Pending")
        case .importing: String(localized: "Importing")
        case .failedPending: String(localized: "Waiting")
        default: String(localized: "Downloading")
        }
    }
}

struct QueueStatusMessage: Codable {
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
    case importing
    case imported
    case failedPending
    case failed
    case ignored
}
