import os
import SwiftUI

@MainActor
@Observable
class ArtistLookup {
    var instance: Instance

    var items: [Artist]?
    var sort: SortOption = .byRelevance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool { searchTask != nil }
    var searchedQuery: String = ""

    private var queries: [String: Artist] = [:]
    private var searchTask: Task<Void, Never>?
    private var searchTaskQuery: String = ""

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum SortOption: Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance
        case byRating

        var label: String {
            switch self {
            case .byRelevance: String(localized: "Relevant", comment: "Media search scope")
            case .byRating: String(localized: "Rating", comment: "Media search scope")
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
                items = try await dependencies.api.lookupArtists(instance, query)
                searchedQuery = query
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "artist.lookup", message: "Artist lookup failed", data: ["query": query, "error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }

            if !Task.isCancelled {
                searchTask = nil
                searchTaskQuery = ""
            }
        }
    }

    func fetch(id: Int) async throws -> Artist? {
        let query = "\(id)"
        if let cached = queries[query] {
            return cached
        }

        let results = try await dependencies.api.lookupArtists(instance, query)

        if let result = results.first {
            queries[query] = result
        }

        return queries[query] ?? nil
    }

    func fetch(mbId: String) async throws -> Artist? {
        let query = "mb:\(mbId)"

        if let cached = queries[query] {
            return cached
        }

        let results = try await dependencies.api.lookupArtists(instance, query)

        if let result = results.first {
            queries[query] = result
        }

        return queries[query] ?? nil
    }

    // consider caching this for performance
    var sortedItems: [Artist] {
        let items = items ?? []

        guard sort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch sort {
            case .byRelevance:
                false // see `.byRelevance` guard above
            case .byRating:
                $0.ratingScore > $1.ratingScore
            }
        }
    }
}
