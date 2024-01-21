import SwiftUI

@Observable
class MovieLookupModel {
    var movies: [MovieLookup]?
    var error: Error?

    var hasError: Bool = false
    var isSearching: Bool = false

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
        }

        isSearching = false
    }
}

struct MovieLookup: Identifiable, Codable {
    var id: Int {
        tmdbId
    }
    let tmdbId: Int
    let title: String
    let year: Int
    let remotePoster: String?
    let images: [MovieImage]
}
