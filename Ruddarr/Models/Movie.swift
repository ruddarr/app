import SwiftUI

@Observable
class MovieModel {
    var movies: [Movie] = []
    var error: Error?

    func fetch(_ instance: Instance) async {
        do {
            movies = try await dependencies.api.fetchMovies(instance)
        } catch {
            self.error = error
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
    var added: Date

    let images: [MovieImage]

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var remoteFanart: String? {
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
