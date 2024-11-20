import os
import SwiftUI

@MainActor
@Observable
class Movies {
    var instance: Instance

    var items: [Movie] = []
    var itemsCount: Int = 0

    var cachedItems: [Movie] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    private var alternateTitles: [Movie.ID: String] = [:]
    private var sortAndFilterTask: Task<Void, Never>?

    enum Operation {
        case fetch
        case get(Movie)
        case add(Movie)
        case update(Movie, Bool)
        case delete(Movie, Bool)
        case download(String, Int, Int?)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func updateCachedItems(_ sort: MovieSort, _ searchQuery: String) {
        sortAndFilterTask?.cancel()

        sortAndFilterTask = Task { @MainActor in
            let items = self.items
            let alternateTitles = self.alternateTitles

            cachedItems = await Task.detached(priority: .userInitiated) {
                Self.filterAndSortItems(items, alternateTitles, sort, searchQuery)
            }.result.get()
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

    func delete(_ movie: Movie, addExclusion: Bool = false) async -> Bool {
        await request(.delete(movie, addExclusion))
    }

    func download(guid: String, indexerId: Int, movieId: Int?) async -> Bool {
        await request(.download(guid, indexerId, movieId))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

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
            computeAlternateTitles()
            await Spotlight(instance.id).index(items, delay: .seconds(5))

            leaveBreadcrumb(.info, category: "movies", message: "Fetched movies", data: ["count": items.count])

        case .get(let movie):
            if let index = items.firstIndex(where: { $0.id == movie.id }) {
                let item = try await dependencies.api.getMovie(movie.id, instance)

                if items[index] != item {
                    items[index] = item
                }
            }

        case .add(let movie):
            items.append(try await dependencies.api.addMovie(movie, instance))

        case .update(let movie, let moveFiles):
            _ = try await dependencies.api.updateMovie(movie, moveFiles, instance)

        case .delete(let movie, let addExclusion):
            _ = try await dependencies.api.deleteMovie(movie, addExclusion, instance)
            items.removeAll(where: { $0.guid == movie.guid })

        case .download(let guid, let indexerId, let movieId):
            let payload = DownloadReleaseCommand(guid: guid, indexerId: indexerId, movieId: movieId)
            _ = try await dependencies.api.downloadRelease(payload, instance)

        case .command(let command):
            _ = try await dependencies.api.command(command, instance)
        }
    }

    nonisolated private static func filterAndSortItems(
        _ items: [Movie],
        _ alternateTitles: [Movie.ID: String],
        _ sort: MovieSort,
        _ searchQuery: String
    ) -> [Movie] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let comparator = sort.option.compare

        return items
            .filter(sort.filter.filter)
            .filter {
                guard !query.isEmpty else { return true }
                return $0.title.localizedCaseInsensitiveContains(query)
                    || $0.studio?.localizedCaseInsensitiveContains(query) ?? false
                    || alternateTitles[$0.id]?.localizedCaseInsensitiveContains(query) ?? false
            }
            .sorted { lhs, rhs in
                sort.isAscending ? comparator(lhs, rhs) : comparator(rhs, lhs)
            }
    }

    private func computeAlternateTitles() {
        if alternateTitles.count == items.count {
            return
        }

        Task.detached(priority: .background) {
            let titles: [Movie.ID: String] = await Dictionary(
                uniqueKeysWithValues: self.items.map { item in
                    (item.id, item.alternateTitlesString())
                }
            )

            await MainActor.run {
                self.alternateTitles = titles
            }
        }
    }
}
