import Foundation
import Combine
import Sentry

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

    let downloadingKeys = CurrentValueSubject<Set<String>, Never>([])

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

    var activeItems: [QueueItem] {
        items.values.flatMap { $0 }.filter { $0.trackedDownloadState != .imported }
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

        let issues = items.flatMap { $0.value }.filter { $0.hasIssue }
        let uniqueIssues = Set(issues.map { $0.taskGroup }).count

        if itemsWithIssues != uniqueIssues {
            itemsWithIssues = uniqueIssues
        }

        let keys = downloadingKeySet()

        if downloadingKeys.value != keys {
            downloadingKeys.send(keys)
        }

        isLoading = false
    }

    private func downloadingKeySet() -> Set<String> {
        Set(activeItems.flatMap { item -> [String] in
            guard let instance = item.instanceId?.uuidString else { return [] }
            var keys: [String] = []
            if let movieId = item.movieId { keys.append("m:\(instance):\(movieId)") }
            if let seriesId = item.seriesId { keys.append("s:\(instance):\(seriesId)") }
            return keys
        })
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

    func isDownloading(_ movie: Movie, instanceId: Instance.ID) -> Bool {
        activeItems.contains { $0.movieId == movie.id && $0.instanceId == instanceId }
    }

    func isDownloading(_ series: Series, instanceId: Instance.ID) -> Bool {
        activeItems.contains { $0.seriesId == series.id && $0.instanceId == instanceId }
    }

    func isDownloading(_ episode: Episode, instanceId: Instance.ID) -> Bool {
        activeItems.contains { $0.episodeId == episode.id && $0.instanceId == instanceId }
    }

    func isDownloading(season seasonNumber: Int, of series: Series, instanceId: Instance.ID) -> Bool {
        activeItems.contains {
            $0.seriesId == series.id && $0.seasonNumber == seasonNumber && $0.instanceId == instanceId
        }
    }
}
