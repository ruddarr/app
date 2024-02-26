import os
import SwiftUI

@Observable
class MovieLookup {
    var instance: Instance

    var items: [Movie]?
    var sort: SortOption = .byRelevance
    var error: Error?

    var isSearching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum SortOption: String, Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance = "Relevance"
        case byYear = "Year"
        case byPopularity = "Popularity"
    }

    func reset() {
        items = nil
    }

    func search(query: String) async {
        error = nil

        guard !query.isEmpty else {
            items = []
            return
        }

        do {
            isSearching = true
            items = try await dependencies.api.lookupMovies(instance, query)
        } catch is CancellationError {
            // do nothing
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "movie.lookup", message: "Movie lookup failed", data: ["query": query, "error": error])
        }

        isSearching = false
    }

    // consider caching this for performance
    var sortedItems: [Movie] {
        let items = items ?? []

        guard sort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch sort {
            case .byRelevance: $0.id < $1.id
            case .byYear: $0.year < $1.year
            case .byPopularity: $0.popularity ?? 0 < $1.popularity ?? 0
            }
        }
    }
}
