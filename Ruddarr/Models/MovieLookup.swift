import SwiftUI

class MovieLookupModel: ObservableObject {
    @Published var movies: [MovieLookup] = []
    @Published var error: ApiError?

    func search(_ instance: Instance, query: String) async {
        guard !query.isEmpty else {
            movies = []
            return
        }

        let urlString = "\(instance.url)/api/v3/movie/lookup?term=\(query)"
        // let urlString = "https://pub-5e0e3f7fd2d0441b82048eafc31ac436.r2.dev/movie-lookup.json"

        let url = URL(string: urlString)!

        await Api<[MovieLookup]>.call(
            url: url,
            authorization: instance.apiKey
        ) { data in
            self.movies = data
        } failure: { error in
            self.error = error

            print("MovieLookupModel.search(): \(error)")
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
