import os
import SwiftUI

@Observable
class MovieLookup {
    var instance: Instance

    var items: [Movie]?
    var sort: SortOption = .byRelevance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool { searchTask != nil }
    var searchedQuery: String = ""

    private var searchTask: Task<Void, Never>?

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum SortOption: Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance
        case byYear
        case byPopularity

        var label: LocalizedStringKey {
            switch self {
            case .byRelevance: "Relevant"
            case .byYear: "Latest"
            case .byPopularity: "Popular"
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
        searchTask?.cancel()

        error = nil
        items = []

        guard !query.isEmpty else {
            items = []
            return
        }

        searchTask = Task {
            do {
                items = try await dependencies.api.lookupMovies(instance, query)
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "movie.lookup", message: "Movie lookup failed", data: ["query": query, "error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }

            if !Task.isCancelled {
                searchTask = nil
            }
        }
    }

    // consider caching this for performance
    var sortedItems: [Movie] {
        let items = items ?? []

        guard sort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch sort {
            case .byRelevance:
                $0.id < $1.id // see `.byRelevance guard above
            case .byYear:
                $0.sortYear > $1.sortYear
            case .byPopularity:
                $0.popularity ?? 0 > $1.popularity ?? 0
            }
        }
    }
}
