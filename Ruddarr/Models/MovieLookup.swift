import os
import SwiftUI

@Observable
class MovieLookupModel {
    var movies: [Movie]?
    var error: Error?

    var hasError: Bool = false
    var isSearching: Bool = false

    private let log: Logger = logger("movie.lookup")

    func search(_ instance: Instance, query: String) async {
        movies = nil
        error = nil
        hasError = false

        guard !query.isEmpty else {
            movies = []
            return
        }

        do {
            isSearching = true
            movies = try await dependencies.api.lookupMovies(instance, query)
        } catch {
            self.error = error
            self.hasError = true

            log.error("Movie lookup failed: \(error)")
        }

        isSearching = false
    }
}
