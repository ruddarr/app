import os
import SwiftUI

@Observable
class Movies {
    var instance: Instance
    var items: [Movie] = []
    var error: Error?
    var isWorking: Bool = false // enum Status { case idle, case working, case failed(Error) }

    private let log: Logger = logger("model.movies")

    enum Operation {
        case fetch
        case add(Movie)
        case update(Movie)
        case delete(Movie)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: Movie.ID) -> Binding<Movie>? {
        guard let index = items.firstIndex(where: { $0.movieId == id }) else {
            return nil
        }

        return Binding(
            get: { self.items[index] },
            set: { self.items[index] = $0 }
        )
    }

    func byTmdbId(_ tmdbId: Int) -> Movie? {
        items.first(where: { $0.tmdbId == tmdbId })
    }

    func fetch() async -> Bool {
        return await request(.fetch)
    }

    func add(_ movie: Movie) async -> Bool {
        return await request(.add(movie))
    }

    func update(_ movie: Movie) async -> Bool {
        return await request(.update(movie))
    }

    func delete(_ movie: Movie) async -> Bool {
        return await request(.delete(movie))
    }

    func request(_ operation: Operation) async -> Bool {
        error = nil
        isWorking = true

        do {
            switch operation {
            case .fetch:
                items = try await dependencies.api.fetchMovies(instance)

            case .add(let movie):
                items.append(try await dependencies.api.addMovie(movie, instance))

            case .update(let movie):
                throw AppError("WTF")
                _ = try await dependencies.api.updateMovie(movie, instance)

            case .delete(let movie):
                _ = try await dependencies.api.deleteMovie(movie, instance)
                items.removeAll(where: { $0.movieId == movie.movieId })
            }
        } catch {
            self.error = error

            log.error("Movies.request() failed: \(error, privacy: .public)")
        }

        isWorking = false

        return error == nil
    }
}
