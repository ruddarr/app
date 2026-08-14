import SwiftUI
import Sentry

@MainActor
@Observable
class SeriesLookup {
    var instance: Instance

    var items: [Series]?
    var sort: SortOption = .byRelevance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool { searchTask != nil }
    var searchedQuery: String = ""

    private var queries: [String: Series] = [:]
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
        items?.isEmpty ?? true
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
                items = try await dependencies.api.sonarr.lookup(instance, query)
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

    func fetch(tmdb: Int) async throws -> Series? {
        let query = "tmdb:\(tmdb)"

        if let cached = queries[query] {
            return cached
        }

        let results = try await dependencies.api.sonarr.lookup(instance, query)

        if let result = results.first {
            queries[query] = result
        }

        return queries[query] ?? nil
    }

    func updateItem(_ series: Series) {
        if let index = items?.firstIndex(where: { $0.tvdbId == series.tvdbId }) {
            items?[index] = series
        }

        if let tmdbId = series.tmdbId {
            queries["tmdb:\(tmdbId)"] = series
        }
    }

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
