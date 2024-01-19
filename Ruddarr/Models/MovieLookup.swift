import SwiftUI

@Observable
class MovieLookupModel {
    var movies: [MovieLookup] = []
    var error: Error?

    func search(_ instance: Instance, query: String) async {
        guard !query.isEmpty else {
            movies = []
            return
        }
        
        do {
            movies = try await dependencies.api.lookupMovies(instance, query)
        } catch {
            self.error = error
        }
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
