import os
import SwiftUI

@MainActor
@Observable
class SeriesModel {
    var instance: Instance

    var items: [Series] = []
    var itemsCount: Int = 0

    var cachedItems: [Series] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    private var alternateTitles: [Series.ID: String] = [:]
    private var sortAndFilterTask: Task<Void, Never>?

    enum Operation {
        case fetch
        case get(Series)
        case add(Series)
        case push(Series)
        case update(Series, Bool)
        case delete(Series, Bool, Bool)
        case download(String, Int, Int?, Int?, Int?)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func updateCachedItems(_ sort: SeriesSort, _ searchQuery: String) {
        sortAndFilterTask?.cancel()

        sortAndFilterTask = Task {
            let items = self.items
            let alternateTitles = self.alternateTitles

            let sortedItems = await Task.detached(priority: .userInitiated) {
                Self.filterAndSortItems(items, alternateTitles, sort, searchQuery)
            }.value

            await MainActor.run {
                cachedItems = sortedItems
            }
        }
    }

    func byId(_ id: Series.ID) -> Series? {
        self.items.first(where: { $0.guid == id })
    }

    func byId(_ id: Series.ID) -> Binding<Series> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.items.firstIndex(where: { $0.guid == id }) else {
                    // item will be removed while still displayed briefly before navigation occurs
                    return .void
                }

                return self.items[index]
            },
            set: { [weak self] newValue in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    self?.items.append(newValue)
                    return
                }

                self?.items[index] = newValue
            }
        )
    }

    func byTvdbId(_ tvdbId: Int) -> Series? {
        items.first(where: { $0.tvdbId == tvdbId })
    }
    func byTmdbId(_ tmdbId: Int) -> Series? {
        items.first(where: { $0.tmdbId == tmdbId })
    }

    func fetch() async -> Bool {
        await request(.fetch)
    }

    func get(_ series: Series, silent: Bool = false) async -> Bool {
        await request(.get(series), silent: silent)
    }

    func add(_ series: Series) async -> Bool {
        await request(.add(series))
    }

    func push(_ series: Series) async -> Bool {
        await request(.push(series))
    }

    func update(_ series: Series, moveFiles: Bool = false) async -> Bool {
        await request(.update(series, moveFiles))
    }

    func delete(_ series: Series, addExclusion: Bool, deleteFiles: Bool) async -> Bool {
        await request(.delete(series, addExclusion, deleteFiles))
    }

    func download(guid: String, indexerId: Int, seriesId: Int?, seasonId: Int?, episodeId: Int?) async -> Bool {
        await request(.download(guid, indexerId, seriesId, seasonId, episodeId))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

    func request(_ operation: Operation, silent: Bool = false) async -> Bool {
        if !silent {
            error = nil
            isWorking = true
        }

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            if !silent {
                error = apiError
            }

            leaveBreadcrumb(.error, category: "series", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            if !silent {
                self.error = API.Error(from: error)
            }
        }

        if !silent {
            isWorking = false
        }

        return error == nil
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch:
            items = try await dependencies.api.fetchSeries(instance)
            itemsCount = items.count
            computeAlternateTitles()
            await Spotlight(instance.id).index(items, delay: .seconds(5))

            leaveBreadcrumb(.info, category: "series", message: "Fetched series", data: ["count": items.count])

        case .get(let series):
            if let index = items.firstIndex(where: { $0.id == series.id }) {
                let item = try await dependencies.api.getSeries(series.id, instance)

                if items[index] != item {
                    items[index] = item
                }
            }

        case .add(let series):
            items.append(try await dependencies.api.addSeries(series, instance))

        case .push(let series):
            _ = try await dependencies.api.pushSeries(series, instance)

        case .update(let series, let moveFiles):
            _ = try await dependencies.api.updateSeries(series, moveFiles, instance)

        case .delete(let series, let addExclusion, let deleteFiles):
            _ = try await dependencies.api.deleteSeries(series, addExclusion, deleteFiles, instance)
            items.removeAll(where: { $0.guid == series.guid })

        case .download(let guid, let indexerId, let seriesId, let seasonId, let episodeId):
            let payload = episodeId == nil
                ? DownloadReleaseCommand(guid: guid, indexerId: indexerId, seriesId: seriesId, seasonId: seasonId)
                : DownloadReleaseCommand(guid: guid, indexerId: indexerId, episodeId: episodeId)
            _ = try await dependencies.api.downloadRelease(payload, instance)

        case .command(let command):
            _ = try await dependencies.api.command(command, instance)
        }
    }

    nonisolated private static func filterAndSortItems(
        _ items: [Series],
        _ alternateTitles: [Series.ID: String],
        _ sort: SeriesSort,
        _ searchQuery: String
    ) -> [Series] {
        let query = searchQuery.trimmed()
        let comparator = sort.option.compare

        return items
            .filter(sort.filter.filter)
            .filter {
                guard !query.isEmpty else { return true }
                return $0.title.localizedCaseInsensitiveContains(query)
                    || $0.network?.localizedCaseInsensitiveContains(query) ?? false
                    || alternateTitles[$0.id]?.localizedCaseInsensitiveContains(query) ?? false
            }
            .sorted { lhs, rhs in
                sort.isAscending ? comparator(lhs, rhs) : comparator(rhs, lhs)
            }
    }

    private func computeAlternateTitles() {
        if alternateTitles.count == items.count {
            return
        }

        Task.detached(priority: .background) {
            let titles: [Series.ID: String] = await Dictionary(
                uniqueKeysWithValues: self.items.map { item in
                    (item.id, item.alternateTitlesString())
                }
            )

            await MainActor.run {
                self.alternateTitles = titles
            }
        }
    }
}
