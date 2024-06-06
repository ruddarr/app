import os
import SwiftUI

@Observable
class SeriesLookup {
    var instance: Instance

    var items: [Series]?

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool { searchTask != nil }
    var searchedQuery: String = ""

    private var searchTask: Task<Void, Never>?

    init(_ instance: Instance) {
        self.instance = instance
    }

    func reset() {
        items = nil
    }

    func isEmpty() -> Bool {
        items == nil || items?.count == 0
    }

    func noResults(_ query: String) -> Bool {
        if isSearching || query.isEmpty {
            return false
        }

        return searchedQuery == query && isEmpty()
    }

    func search(query: String) async {
        searchTask?.cancel()

        error = nil
        items = []

        guard !query.isEmpty else {
            items = []
            return
        }

        searchTask = Task {
            do {
                items = try await dependencies.api.lookupSeries(instance, query)
                searchedQuery = query
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "series.lookup", message: "Series lookup failed", data: ["query": query, "error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }

            if !Task.isCancelled {
                searchTask = nil
            }
        }
    }
}
