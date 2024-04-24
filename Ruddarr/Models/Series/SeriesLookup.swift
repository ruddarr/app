import os
import SwiftUI

@Observable
class SeriesLookup {
    var instance: Instance

    var items: [Series]?
    var sort: SortOption = .byRelevance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum SortOption: Identifiable, CaseIterable {
        var id: Self { self }

        case byRelevance
        case byYear
        // case byPopularity

        var label: LocalizedStringKey {
            switch self {
            case .byRelevance: "Relevant"
            case .byYear: "Latest"
            // TOOD: needs fixing
            // case .byPopularity: "Popular"
            }
        }
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
            items = try await dependencies.api.lookupSeries(instance, query)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.lookup", message: "Series lookup failed", data: ["query": query, "error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSearching = false
    }

    // consider caching this for performance
    var sortedItems: [Series] {
        let items = items ?? []

        guard sort != .byRelevance else {
            return items
        }

        return items.sorted {
            switch sort {
            case .byRelevance: $0.id < $1.id // see guard above
            case .byYear: $0.year > $1.year
            // case .byPopularity: $0.popularity ?? 0 > $1.popularity ?? 0
            }
        }
    }
}
