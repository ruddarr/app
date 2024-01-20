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
    var added: String

    let images: [MovieImage]

    var dateAdded: Date {
        ISO8601DateFormatter().date(from: self.added)
            ?? DateFormatter().date(from: "01/01/1984")!
    }

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
