import SwiftUI

class MovieModel: ObservableObject {
    @Published var movies: [Movie] = []

    @MainActor
    func fetch(_ instance: Instance) async {
        movies = []

        do {
            let urlString = "\(instance.url)/api/v3/movie"
            // let urlString = "https://pub-5e0e3f7fd2d0441b82048eafc31ac436.r2.dev/movies.json"
            let url = URL(string: urlString)!

            var request = URLRequest(url: url)
            request.setValue("8f45bce99e254f888b7a2ba122468dbe", forHTTPHeaderField: "X-Api-Key")

            print("fetching... " + urlString)

            let (data, _) = try await URLSession.shared.data(for: request)
            movies = try JSONDecoder().decode([Movie].self, from: data)
        } catch {
            print("MovieModel.fetch(): \(error)")
        }
    }
}

struct Movie: Identifiable, Codable {
    let id: Int
    let title: String
    let sortTitle: String
    let studio: String?
    let year: Int
    let sizeOnDisk: Int?
    let monitored: Bool
    let images: [MovieImage]

    var remotePoster: String? {
        // if let local = self.images.first(where: { $0.coverType == "poster" }) {
        //     return "http://10.0.1.5:8310\(local.url)"
        // }

        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var remoteFanart: String? {
            // if let local = self.images.first(where: { $0.coverType == "poster" }) {
            //     return "http://10.0.1.5:8310\(local.url)"
            // }

            if let remote = self.images.first(where: { $0.coverType == "fanart" }) {
                return remote.remoteURL
            }

            return nil
        }
}

struct MovieImage: Codable {
    let coverType: String
    let remoteURL: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
        case url
    }
}
