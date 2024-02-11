import os
import SwiftUI

@Observable
class MovieLookup {
    var instance: Instance

    var items: [Movie]?
    var error: Error?

    var isSearching: Bool = false

    private let log: Logger = logger("models.movie.lookup")

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

            log.error("Failed to look up movies (\(query)): \(error)")
        }

        isSearching = false
    }
}
