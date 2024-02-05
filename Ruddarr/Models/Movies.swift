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
        case command(Movie, RadarrCommand.Command)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: Movie.ID) -> Binding<Movie?> {
        Binding(
            get: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.movieId == id }) else {
                    return nil
                }
                return self?.items[index]
            },
            set: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.movieId == id })
                else {
                    if let newValue = $0 {
                        self?.items.append(newValue)
                    }
                    return
                }
                if let newValue = $0 {
                    self?.items[index] = newValue
                } else {
                    self?.items.remove(at: index)
                }
            }
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

    func command(_ movie: Movie, command: RadarrCommand.Command) async -> Bool {
        return await request(.command(movie, command))
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
                _ = try await dependencies.api.updateMovie(movie, instance)

            case .delete(let movie):
                _ = try await dependencies.api.deleteMovie(movie, instance)
                items.removeAll(where: { $0.movieId == movie.movieId })

            case .command(let movie, let commandName):
                let command = switch commandName {
                case .automaticSearch: RadarrCommand(name: commandName, movieIds: [movie.movieId!])
                }

                _ = try await dependencies.api.command(command, instance)
            }
        } catch {
            self.error = error

            log.error("Movies.request() failed: \(error)")
        }

        isWorking = false

        return error == nil
    }
}
