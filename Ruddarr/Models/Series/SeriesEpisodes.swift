import SwiftUI
import Sentry

@MainActor
@Observable
class SeriesEpisodes {
    var instance: Instance

    var items: [Episode] = [] {
        didSet { indexRuntimes() }
    }

    private var runtimes: [Episode.ID: Int] = [:]

    // `items` can be seeded with partial data (e.g. by the calendar sheets),
    // so track which series was actually fetched from the instance
    private var fetchedSeriesId: Series.ID?
    private var maybeFetchTask: Task<Void, Never>?

    var history: [MediaHistoryEvent] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false
    var isMonitoring: Episode.ID = 0

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: Episode.ID) -> Episode? {
        items.first { $0.id == id }
    }

    func runtime(for id: Episode.ID) -> Int? {
        runtimes[id]
    }

    func bySeasonId(_ season: Season.ID) -> [Episode] {
        items.filter { $0.seasonNumber == season }
    }

    func fetched(_ series: Series) -> Bool {
        fetchedSeriesId == series.id
    }

    /// Seeds `items` as if they had been fetched, unlike the partial data
    /// the calendar sheets seed, which is meant to be backfilled.
    func seed(_ episodes: [Episode]) {
        items = episodes
        fetchedSeriesId = episodes.first?.seriesId
    }

    func maybeFetch(_ series: Series) async {
        let force = abs(series.added.timeIntervalSinceNow) < 30

        guard !fetched(series) || force else { return }

        // the calendar sheet installs the series, season and episode views at once,
        // join an in-flight load instead of issuing the same request three times.
        // `fetch(_:)` is left alone so pull-to-refresh always hits the instance
        if let maybeFetchTask {
            return await maybeFetchTask.value
        }

        let task = Task { await fetch(series) }
        maybeFetchTask = task
        defer { maybeFetchTask = nil }

        await task.value
    }

    func fetch(_ series: Series) async {
        error = nil
        isFetching = true

        if let episode = items.first, episode.seriesId != series.id {
            items = []
            fetchedSeriesId = nil
        }

        do {
            let newItems = try await dependencies.api.fetchEpisodes(series.id, instance)

            if items != newItems {
                items = newItems
            }

            fetchedSeriesId = series.id

            if instance.version?.hasPrefix("3.") == true, newItems.contains(where: \.hasFile) {
                error = API.Error(from: AppError.upgradeRequired(.sonarr, to: "4.0"))
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episodes fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }

    func monitor(_ episodes: [Episode.ID], _ monitored: Bool) async -> Bool {
        error = nil
        isMonitoring = episodes[0]

        do {
            _ = try await dependencies.api.monitorEpisode(episodes, monitored, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episode monitor failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isMonitoring = 0

        return error == nil
    }

    func fetchHistory(_ episode: Episode) async {
        do {
            history = try await dependencies.api.getEpisodeHistory(episode.id, instance).records
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episodes history fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }
    }

    private func indexRuntimes() {
        runtimes = Dictionary(
            items.compactMap { episode in
                episode.runtime.map { (episode.id, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
