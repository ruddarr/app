import Foundation
import Combine
import Sentry

enum QueueKey: Hashable {
    case movie(instanceId: UUID, id: Int)
    case series(instanceId: UUID, id: Int)
}

@MainActor
@Observable
class Queue {
    static let shared = Queue()

    private var pollingTask: Task<Void, Never>?

    var error: API.Error?

    var isLoading: Bool = false
    var performRefresh: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [QueueItem]] = [:]
    var itemsWithIssues: Int = 0

    private var revision: Int = 0
    private var deletedItems: [Instance.ID: Set<QueueItem.ID>] = [:]
    private var deletedDownloads: [Instance.ID: Set<String>] = [:]

    let statuses = CurrentValueSubject<[QueueKey: QueueItemStatus], Never>([:])
    private(set) var active: [QueueItem] = []

    private init() {
        let interval: TimeInterval = isRunningIn(.preview) ? 30 : 5

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))

                guard let self else { return }

                await self.fetchTasks()

                if self.performRefresh {
                    await self.refreshDownloadClients()
                }
            }
        }
    }

    func fetchTasks() async {
        guard !isLoading else { return }

        error = nil
        isLoading = true

        let fetchRevision = revision

        await withThrowingTaskGroup(of: (Instance.ID, QueueItems).self) { group in
            for instance in instances {
                group.addTask {
                    (instance.id, try await dependencies.api.instance.queue(instance))
                }
            }

            while let result = await group.nextResult() {
                switch result {
                case .success(let (instanceId, queue)):
                    if fetchRevision == revision {
                        if queue.totalRecords <= queue.records.count {
                            deletedItems[instanceId]?.formIntersection(queue.records.map(\.id))
                            deletedDownloads[instanceId]?.formIntersection(queue.records.compactMap(\.downloadId))
                        }

                        items[instanceId] = queue.records.filter {
                            !isDeleted($0, instanceId: instanceId)
                        }
                    }
                case .failure(is CancellationError):
                    break
                case .failure(let apiError as API.Error):
                    error = apiError
                    // leaveBreadcrumb(.error, category: "queue", message: "Fetch failed", data: ["error": apiError])
                case .failure(let otherError):
                    error = API.Error(from: otherError)
                }
            }
        }

        recomputeDerivedState()

        isLoading = false
    }

    private func recomputeDerivedState() {
        let active = items.values.flatMap { $0 }.filter { $0.trackedDownloadState != .imported }
        if active != self.active { self.active = active }

        let issues = items.flatMap { $0.value }.filter(\.hasIssue)
        let uniqueIssues = Set(issues.map(\.taskGroup)).count

        if itemsWithIssues != uniqueIssues {
            itemsWithIssues = uniqueIssues
        }

        let statuses = activeStatuses()

        if self.statuses.value != statuses {
            self.statuses.send(statuses)
        }
    }

    private func activeStatuses() -> [QueueKey: QueueItemStatus] {
        var statuses: [QueueKey: QueueItemStatus] = [:]

        for item in active {
            guard let instanceId = item.instanceId else { continue }

            var keys: [QueueKey] = []
            if let movieId = item.movieId { keys.append(.movie(instanceId: instanceId, id: movieId)) }
            if let seriesId = item.seriesId { keys.append(.series(instanceId: instanceId, id: seriesId)) }

            let status = item.queueStatus

            // Keep the highest-precedence status when a key has multiple active items
            for key in keys {
                statuses[key] = max(statuses[key] ?? status, status)
            }
        }

        return statuses
    }

    func markImporting(_ item: QueueItem) {
        guard let instanceId = item.instanceId, let downloadId = item.downloadId else { return }
        guard var records = items[instanceId] else { return }

        for index in records.indices where records[index].downloadId == downloadId {
            records[index].markImporting()
        }

        items[instanceId] = records

        recomputeDerivedState()
    }

    func markDeleted(_ item: QueueItem) {
        guard let instanceId = item.instanceId else { return }

        revision += 1
        deletedItems[instanceId, default: []].insert(item.id)

        if let downloadId = item.downloadId {
            deletedDownloads[instanceId, default: []].insert(downloadId)
        }

        items[instanceId]?.removeAll { isDeleted($0, instanceId: instanceId) }

        recomputeDerivedState()
    }

    private func isDeleted(_ item: QueueItem, instanceId: Instance.ID) -> Bool {
        if deletedItems[instanceId]?.contains(item.id) == true { return true }
        guard let downloadId = item.downloadId else { return false }
        return deletedDownloads[instanceId]?.contains(downloadId) == true
    }

    func refreshDownloadClients() async {
        for instance in instances {
            do {
                _ = try await dependencies.api.instance.command(.refreshDownloads, instance)
            } catch is CancellationError {
                // do nothing
            } catch {
                leaveBreadcrumb(.error, category: "queue", message: "Refresh failed", data: ["error": error])
            }
        }
    }

    func queueStatus(_ movie: Movie, instanceId: Instance.ID) -> QueueItemStatus? {
        active.highestStatus { $0.movieId == movie.id && $0.instanceId == instanceId }
    }

    func queueStatus(_ series: Series, instanceId: Instance.ID) -> QueueItemStatus? {
        active.highestStatus { $0.seriesId == series.id && $0.instanceId == instanceId }
    }

    func queueStatus(_ episode: Episode, instanceId: Instance.ID) -> QueueItemStatus? {
        active.highestStatus { $0.episodeId == episode.id && $0.instanceId == instanceId }
    }

    func queueStatus(season seasonNumber: Int, of series: Series, instanceId: Instance.ID) -> QueueItemStatus? {
        active.highestStatus {
            $0.seriesId == series.id && $0.seasonNumber == seasonNumber && $0.instanceId == instanceId
        }
    }
}
