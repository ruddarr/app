import os
import SwiftUI

@Observable
class SeriesLookup {
    var instance: Instance

    var items: [Series]?

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
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
}
