import SwiftUI

@Observable
class MovieModel {
    var movies: [Movie] = []
    var error: ApiError?

    func fetch(_ instance: Instance) async {
        do {
            movies = try await dependencies.api.fetchMovies(instance)
        } catch let error as ApiError {
            self.error = error
            print("MovieModel.fetch(): \(error)")
        } catch {
            // TODO: this is what we get for fitting my untyped error from `throws` to your strongly typed model.
            assertionFailure("Unknown error type \(error)")
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
