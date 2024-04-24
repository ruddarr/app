import os
import SwiftUI

@Observable
class SeriesModel {
    var instance: Instance

    var items: [Series] = []
    var itemsCount: Int = 0

    var cachedItems: [Series] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    enum Operation {
        case fetch
        case add(Series)
        case update(Series, Bool)
        case delete(Series)
        // case download(String, Int)
        case command(Series, SonarrCommand.Command)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func sortAndFilterItems(_ sort: SeriesSort, _ searchQuery: String) {
        cachedItems = sort.filter.filtered(items)

        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        if !query.isEmpty {
            cachedItems = cachedItems.filter { series in
                series.sortTitle.localizedCaseInsensitiveContains(query) ||
                series.network?.localizedCaseInsensitiveContains(query) ?? false ||
                series.alternateTitlesString?.localizedCaseInsensitiveContains(query) ?? false
            }
        }

        cachedItems = cachedItems.sorted(by: sort.option.isOrderedBefore)

        if !sort.isAscending {
            cachedItems = cachedItems.reversed()
        }
    }

    func byId(_ id: Series.ID) -> Binding<Series?> {
        Binding(
            get: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    return nil
                }

                return self?.items[index]
            },
            set: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    if let newValue = $0 {
                        self?.items.append(newValue)
                    }

                    return
                }

                if let newValue = $0 {
                    self?.items[index] = newValue
                } else {
                    self?.items.remove(at: index)
                }
            }
        )
    }

    func byTvdbId(_ tvdbId: Int) -> Series? {
        items.first(where: { $0.tvdbId == tvdbId })
    }

    func fetch() async -> Bool {
        await request(.fetch)
    }

    func add(_ series: Series) async -> Bool {
        await request(.add(series))
    }

    // TODO: `moveFiles` used?
    func update(_ series: Series, moveFiles: Bool = false) async -> Bool {
        await request(.update(series, moveFiles))
    }

    func delete(_ series: Series) async -> Bool {
        await request(.delete(series))
    }

//    func download(guid: String, indexerId: Int) async -> Bool {
//        await request(.download(guid, indexerId))
//    }

    func command(_ series: Series, command: SonarrCommand.Command) async -> Bool {
        await request(.command(series, command))
    }

    @MainActor
    func request(_ operation: Operation) async -> Bool {
        error = nil
        isWorking = true

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false

        return error == nil
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch:
            items = try await dependencies.api.fetchSeries(instance)
            itemsCount = items.count
            leaveBreadcrumb(.info, category: "series", message: "Fetched series", data: ["count": items.count])
            setAlternateTitlesStrings()

//        case .add(let series):
//            items.append(try await dependencies.api.addSeries(series, instance))

//        case .update(let series, let moveFiles):
//            _ = try await dependencies.api.updateSeries(series, moveFiles, instance)
//
//        case .delete(let series):
//            _ = try await dependencies.api.deleteSeries(series, instance)
//            items.removeAll(where: { $0.guid == movie.guid })
//
//        case .download(let guid, let indexerId):
//            _ = try await dependencies.api.downloadRelease(guid, indexerId, instance)
//
//        case .command(let movie, let commandName):
//            let command = switch commandName {
//            case .refresh: RadarrCommand(name: commandName, movieIds: [movie.id])
//            case .automaticSearch: RadarrCommand(name: commandName, movieIds: [movie.id])
//            }
//
//            _ = try await dependencies.api.command(command, instance)
        }
    }

    private func setAlternateTitlesStrings() {
        Task.detached {
            for index in self.items.indices {
                self.items[index].setAlternateTitlesString()
            }
        }
    }
}
