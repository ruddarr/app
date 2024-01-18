import SwiftUI

class MovieModel: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var error: ApiError?

    func fetch(_ instance: Instance) async {
        let url = URL(string: "\(instance.url)/api/v3/movie")!

        await Api<[Movie]>.call(
            url: url,
            authorization: instance.apiKey
        ) { data in
            self.movies = data
        } failure: { error in
            self.error = error

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
