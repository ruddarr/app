import os
import SwiftUI

@Observable
class MovieLookup {
    var instance: Instance

    var items: [Movie]?
    var error: Error?

    var isSearching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
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
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "movie.lookup", message: "Movie lookup failed", data: ["query": query, "error": error])
        }

        isSearching = false
    }
}
