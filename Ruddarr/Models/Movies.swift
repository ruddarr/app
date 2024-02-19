import os
import SwiftUI

@Observable
class Movies {
    var instance: Instance
    var items: [Movie] = []
    var error: Error?

    // enum Status { case idle, case working, case failed(Error) }
    var isWorking: Bool = false

    enum Operation {
        case fetch
        case add(Movie)
        case update(Movie, Bool)
        case delete(Movie)
        case download(String, Int)
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
                guard let index = self?.items.firstIndex(where: { $0.movieId == id }) else {
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
        await request(.fetch)
    }

    func add(_ movie: Movie) async -> Bool {
        await request(.add(movie))
    }

    func update(_ movie: Movie, moveFiles: Bool = false) async -> Bool {
        await request(.update(movie, moveFiles))
    }

    func delete(_ movie: Movie) async -> Bool {
        await request(.delete(movie))
    }

    func download(guid: String, indexerId: Int) async -> Bool {
        await request(.download(guid, indexerId))
    }

    func command(_ movie: Movie, command: RadarrCommand.Command) async -> Bool {
        await request(.command(movie, command))
    }

    @MainActor
    func request(_ operation: Operation) async -> Bool {
        error = nil
        isWorking = true

        do {
            switch operation {
            case .fetch:
                items = try await dependencies.api.fetchMovies(instance)

            case .add(let movie):
                items.append(try await dependencies.api.addMovie(movie, instance))

            case .update(let movie, let moveFiles):
                _ = try await dependencies.api.updateMovie(movie, moveFiles, instance)

            case .delete(let movie):
                _ = try await dependencies.api.deleteMovie(movie, instance)
                items.removeAll(where: { $0.movieId == movie.movieId })

            case .download(let guid, let indexerId):
                _ = try await dependencies.api.downloadRelease(guid, indexerId, instance)

            case .command(let movie, let commandName):
                let command = switch commandName {
                case .refresh: RadarrCommand(name: commandName, movieIds: [movie.movieId!])
                case .automaticSearch: RadarrCommand(name: commandName, movieIds: [movie.movieId!])
                }

                _ = try await dependencies.api.command(command, instance)
            }
        } catch is CancellationError {
            //
        } catch let urlError as URLError where urlError.code == .timedOut {
            self.error = instance.isPrivateIp() ? URLError.timedOutOnPrivateIp : urlError
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "movies", message: "Request failed", data: ["operation": operation, "error": error])
        }

        isWorking = false

        return error == nil
    }
}
