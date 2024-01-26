import os
import SwiftUI

@Observable
class MovieLookup {
    var instance: Instance

    var items: [Movie]?
    var error: Error?

    var hasError: Bool = false
    var isSearching: Bool = false

    private let log: Logger = logger("models.movielookup")

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(query: String) async {
        items = nil
        error = nil
        hasError = false

        guard !query.isEmpty else {
            items = []
            return
        }

        do {
            isSearching = true
            items = try await dependencies.api.lookupMovies(instance, query)
        } catch {
            self.error = error
            self.hasError = true

            log.error("Failed to look up movies (\(query)): \(error, privacy: .public)")
        }

        isSearching = false
    }
}
