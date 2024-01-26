import SwiftUI

@Observable
class MovieModel {
    var movies: [Movie] = []
    var error: Error?

    var hasError: Bool = false
    var isWorking: Bool = false

    func byId(_ id: Int) -> Movie? {
        if let movie = movies.first(where: { $0.id == id }) {
            return movie
        }

        return nil
    }

    func fetch(_ instance: Instance) async {
        error = nil
        hasError = false

        do {
            isWorking = true
            movies = try await dependencies.api.fetchMovies(instance)
        } catch {
            self.error = error
            self.hasError = true
        }

        isWorking = false
    }

    func add(_ movie: Movie, _ instance: Instance) async -> Movie? {
        error = nil
        hasError = false

        do {
            isWorking = true
            return try await dependencies.api.addMovie(movie, instance)
        } catch {
            self.error = error
            self.hasError = true
        }

        isWorking = false

        return nil
    }
}

struct Movie: Identifiable, Codable {
    var id: Int { movieId ?? tmdbId }

    var movieId: Int?
    let tmdbId: Int

    let title: String
    let sortTitle: String
    let studio: String?
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?

    let genres: [String]

    let status: MovieStatus
    var minimumAvailability: MovieStatus

    var monitored: Bool
    var qualityProfileId: Int
    let sizeOnDisk: Int?
    let hasFile: Bool

    var path: String?
    var folderName: String?
    var rootFolderPath: String?

    let added: Date
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?

    let images: [MovieImage]
    let movieFile: MovieFile?

    enum CodingKeys: String, CodingKey {
        case movieId = "id"
        case tmdbId
        case title
        case sortTitle
        case studio
        case year
        case runtime
        case overview
        case certification
        case genres
        case status
        case minimumAvailability
        case monitored
        case qualityProfileId
        case sizeOnDisk
        case hasFile
        case rootFolderPath
        case added
        case inCinemas
        case physicalRelease
        case digitalRelease
        case images
        case movieFile
    }

    var exists: Bool {
        movieId != nil
    }

    var humanRuntime: String {
        let hours = runtime / 60
        let minutes = runtime % 60

        return "\(hours)h \(minutes)m"
    }

    var humanSize: String {
        return ByteCountFormatter().string(
            fromByteCount: Int64(sizeOnDisk ?? 0)
        )
    }

    var humanGenres: String {
        genres.joined(separator: ", ")
    }

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

enum MovieStatus: String, Codable {
    case tba
    case announced
    case inCinemas
    case released
    case deleted

    var label: String {
        return switch self {
        case .tba: "TBA"
        case .announced: "Announced"
        case .inCinemas: "In Cinemas"
        case .released: "Released"
        case .deleted: "Deleted"
        }
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

struct MovieFile: Codable {
    let movieId: Int
}
