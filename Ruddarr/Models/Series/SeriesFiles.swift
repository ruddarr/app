import os
import SwiftUI

@Observable
class SeriesFiles {
    var instance: Instance

    var items: [MediaFile] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func fetched(_ series: Series) -> Bool {
        items.contains { $0.seriesId == series.id }
    }

    func maybeFetch(_ series: Series) async {
        if !fetched(series) { await fetch(series) }
    }

    func fetch(_ series: Series) async {
        items = []
        error = nil
        isFetching = true

        do {
            items = try await dependencies.api.fetchEpisodeFiles(series.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.files", message: "Series files fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }

    func delete(_ file: MediaFile) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteEpisodeFile(file, instance)
            items.remove(at: items.firstIndex { $0.id == file.id } ?? 0)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episode deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }
}
