import os
import SwiftUI

@Observable
class Movies {
    var instance: Instance

    var items: [Movie] = []
    var itemsCount: Int = 0

    var cachedItems: [Movie] = []
    var alternateTitles: [Movie.ID: String] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    enum Operation {
        case fetch
        case get(Movie)
        case add(Movie)
        case update(Movie, Bool)
        case delete(Movie)
        case download(String, Int)
        case command(RadarrCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func sortAndFilterItems(_ sort: MovieSort, _ searchQuery: String) {
        cachedItems = sort.filter.filtered(items)

        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        if !query.isEmpty {
            cachedItems = cachedItems.filter { movie in
                movie.sortTitle.localizedCaseInsensitiveContains(query) ||
                movie.studio?.localizedCaseInsensitiveContains(query) ?? false ||
                alternateTitles[movie.id]?.localizedCaseInsensitiveContains(query) ?? false
            }
        }

        cachedItems = cachedItems.sorted(by: sort.option.isOrderedBefore)

        if !sort.isAscending {
            cachedItems = cachedItems.reversed()
        }
    }

    func byId(_ id: Movie.ID) -> Binding<Movie?> {
        Binding(
            get: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    return nil
                }

                return self?.items[index]
            },
            set: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
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

    func get(_ movie: Movie) async -> Bool {
        await request(.get(movie))
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

    func command(_ command: RadarrCommand) async -> Bool {
        await request(.command(command))
    }

    @MainActor
    func request(_ operation: Operation) async -> Bool {
        error = nil
        isWorking = true

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "movies", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false

        return error == nil
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch:
            items = try await dependencies.api.fetchMovies(instance)
            itemsCount = items.count
            leaveBreadcrumb(.info, category: "movies", message: "Fetched movies", data: ["count": items.count])
            computeAlternateTitles()

        case .get(let movie):
            if let index = items.firstIndex(where: { $0.id == movie.id }) {
                items[index] = try await dependencies.api.getMovie(movie.id, instance)
            }

        case .add(let movie):
            items.append(try await dependencies.api.addMovie(movie, instance))

        case .update(let movie, let moveFiles):
            _ = try await dependencies.api.updateMovie(movie, moveFiles, instance)

        case .delete(let movie):
            _ = try await dependencies.api.deleteMovie(movie, instance)
            items.removeAll(where: { $0.guid == movie.guid })

        case .download(let guid, let indexerId):
            _ = try await dependencies.api.downloadRelease(guid, indexerId, instance)

        case .command(let command):
            _ = try await dependencies.api.radarrCommand(command, instance)
        }
    }

    private func computeAlternateTitles() {
        if alternateTitles.count == items.count {
            return
        }

        Task.detached(priority: .medium) {
            var titles: [Movie.ID: String] = [:]

            for index in self.items.indices {
                titles[self.items[index].id] = self.items[index].alternateTitlesString()
            }

            self.alternateTitles = titles
        }
    }
}
