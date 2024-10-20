import os
import SwiftUI

@Observable
class SeriesLookup {
    var instance: Instance

    var items: [Series]?
    var sort: SortOption = .byRelevance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool { searchTask != nil }
    var searchedQuery: String = ""

    private var searchTask: Task<Void, Never>?
    private var searchTaskQuery: String = ""

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum SortOption: Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance
        case byYear
        case byRating

        var label: LocalizedStringKey {
            switch self {
            case .byRelevance: "Relevant"
            case .byYear: "Latest"
            case .byRating: "Rating"
            }
        }
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
        if searchedQuery == query || searchTaskQuery == query {
            return
        }

        searchTask?.cancel()

        error = nil
        items = []

        guard !query.isEmpty else {
            items = []
            return
        }

        searchTask = Task {
            do {
                searchTaskQuery = query
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
                searchTaskQuery = ""
            }
        }
    }

    // consider caching this for performance
    var sortedItems: [Series] {
        let items = items ?? []

        guard sort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch sort {
            case .byRelevance:
                false // see `.byRelevance` guard above
            case .byYear:
                $0.sortYear > $1.sortYear
            case .byRating:
                $0.ratingScore > $1.ratingScore
            }
        }
    }
}
