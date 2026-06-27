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

    private var timer: Timer?

    var error: API.Error?

    var isLoading: Bool = false
    var performRefresh: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [QueueItem]] = [:]
    var itemsWithIssues: Int = 0

    let statuses = CurrentValueSubject<[QueueKey: QueueItemStatus], Never>([:])
    private(set) var active: [QueueItem] = []

    private init() {
        let interval: TimeInterval = isRunningIn(.preview) ? 30 : 5

        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.fetchTasks()
            }

            Task {
                if await self.performRefresh {
                    await self.refreshDownloadClients()
                }
            }
        }
    }

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

        let active = items.values.flatMap { $0 }.filter { $0.trackedDownloadState != .imported }
        if active != self.active { self.active = active }

        let issues = items.flatMap { $0.value }.filter { $0.hasIssue }
        let uniqueIssues = Set(issues.map { $0.taskGroup }).count

        if itemsWithIssues != uniqueIssues {
            itemsWithIssues = uniqueIssues
        }

        let statuses = activeStatuses()

        if self.statuses.value != statuses {
            self.statuses.send(statuses)
        }

        isLoading = false
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
