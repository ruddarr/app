import os
import Foundation

@Observable
class Movies {
    var instance: Instance

    var items: [Movie] = []

    var error: Error?
    var hasError: Bool = false

    var isWorking: Bool = false

    private let log: Logger = logger("model.movies")

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: Int) -> Movie? {
        items.first(where: { $0.id == id })
    }

    func fetch() async {
        error = nil
        hasError = false

        do {
            isWorking = true
            items = try await dependencies.api.fetchMovies(instance)
        } catch {
            self.error = error
            self.hasError = true

            log.error("Failed to fetch movies: \(error, privacy: .public)")
        }

        isWorking = false
    }

    func add(_ movie: Movie) async -> Movie? {
        error = nil
        hasError = false

        do {
            isWorking = true

            let addedMovie = try await dependencies.api.addMovie(movie, instance)
            items.append(addedMovie)

            return addedMovie
        } catch {
            self.error = error
            self.hasError = true

            log.error("Failed to add movie: \(error, privacy: .public)")
        }

        isWorking = false

        return nil
    }
}
