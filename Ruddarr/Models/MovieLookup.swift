import SwiftUI

class MovieLookupModel: ObservableObject {
    @Published var movies: [MovieLookup] = []
    
    @MainActor
    func search(query: String) async {
        do {
            // let urlString = "http://10.0.1.5:8310/api/v3/movie/lookup"
            let urlString = "https://pub-5e0e3f7fd2d0441b82048eafc31ac436.r2.dev/movie-lookup.json?term=\(query)"
            let url = URL(string: urlString)!
            
            var request = URLRequest(url: url)
            request.setValue("8f45bce99e254f888b7a2ba122468dbe", forHTTPHeaderField: "X-Api-Key")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            movies = try JSONDecoder().decode([MovieLookup].self, from: data)
        } catch {
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
    let images: [MovieImage]
}
