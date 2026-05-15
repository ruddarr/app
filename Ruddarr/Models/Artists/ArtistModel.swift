import os
import SwiftUI

@MainActor
@Observable
class ArtistModel {
    var instance: Instance

    var items: [Artist] = []
    var itemsCount: Int = 0

    var cachedItems: [Artist] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    private var alternateTitles: [Artist.ID: String] = [:]
    private var sortAndFilterTask: Task<Void, Never>?

    enum Operation {
        case fetch
        case get(Artist)
        case add(Artist)
        case push(Artist)
        case update(Artist, Bool)
        case delete(Artist, Bool, Bool)
        case download(String, Int, Int?)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func updateCachedItems(_ sort: ArtistSort, _ searchQuery: String) {
        sortAndFilterTask?.cancel()

        sortAndFilterTask = Task { @MainActor in
            let items = self.items
            let alternateTitles = self.alternateTitles

            cachedItems = await Task.detached(priority: .userInitiated) {
                Self.filterAndSortItems(items, alternateTitles, sort, searchQuery)
            }.result.get()
        }
    }

    func byId(_ id: Artist.ID) -> Artist? {
        self.items.first { $0.guid == id }
    }

    func byId(_ id: Artist.ID) -> Binding<Artist> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.items.firstIndex(where: { $0.guid == id }) else {
                    // item will be removed while still displayed briefly before navigation occurs
                    return .void
                }

                return self.items[index]
            },
            set: { [weak self] newValue in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    self?.items.append(newValue)
                    return
                }

                self?.items[index] = newValue
            }
        )
    }

    func byTadbId(_ tadbId: Int) -> Artist? {
        items.first(where: { $0.tadbId == tadbId })
    }

    func byMbId(_ mbId: String?) -> Artist? {
        items.first(where: { $0.mbId == mbId })
    }

    func fetch() async -> Bool {
        await request(.fetch)
    }

    func get(_ artist: Artist, silent: Bool = false) async -> Bool {
        await request(.get(artist), silent: silent)
    }

    func add(_ artist: Artist) async -> Bool {
        await request(.add(artist))
    }

    func push(_ artist: Artist) async -> Bool {
        await request(.push(artist))
    }

    func update(_ artist: Artist, moveFiles: Bool = false) async -> Bool {
        await request(.update(artist, moveFiles))
    }

    func delete(_ artist: Artist, addExclusion: Bool, deleteFiles: Bool) async -> Bool {
        await request(.delete(artist, addExclusion, deleteFiles))
    }

    func download(guid: String, indexerId: Int, artistId: Int?) async -> Bool {
        await request(.download(guid, indexerId, artistId))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

    func request(_ operation: Operation, silent: Bool = false) async -> Bool {
        if !silent {
            error = nil
            isWorking = true
        }

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            if !silent {
                error = apiError
            }

            leaveBreadcrumb(.error, category: "Artists", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            if !silent {
                self.error = API.Error(from: error)
            }
        }

        if !silent {
            isWorking = false
        }

        return error == nil
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch:
            items = try await dependencies.api.fetchArtists(instance)
            itemsCount = items.count
            computeAlternateTitles()
            await Spotlight(instance.id).index(items, delay: .seconds(5))

            leaveBreadcrumb(.info, category: "Artists", message: "Fetched Artists", data: ["count": items.count])

        case .get(let artist):
            if let index = items.firstIndex(where: { $0.id == artist.id }) {
                let item = try await dependencies.api.getArtist(artist.id, instance)

                if items[index] != item {
                    items[index] = item
                }
            }

        case .add(let artist):
            items.append(try await dependencies.api.addArtist(artist, instance))

        case .push(let artist):
            _ = try await dependencies.api.pushArtist(artist, instance)

        case .update(let artist, let moveFiles):
            _ = try await dependencies.api.updateArtist(artist, moveFiles, instance)

        case .delete(let artist, let addExclusion, let deleteFiles):
            _ = try await dependencies.api.deleteArtist(artist, addExclusion, deleteFiles, instance)
            items.removeAll(where: { $0.guid == artist.guid })

        case .download(let guid, let indexerId, let artistId):
            let payload = DownloadReleaseCommand(guid: guid, indexerId: indexerId, artistId: artistId)
            _ = try await dependencies.api.downloadRelease(payload, instance)

        case .command(let command):
            _ = try await dependencies.api.command(command, instance)
        }
    }

    nonisolated private static func filterAndSortItems(
        _ items: [Artist],
        _ alternateTitles: [Artist.ID: String],
        _ sort: ArtistSort,
        _ searchQuery: String
    ) -> [Artist] {
        let query = searchQuery.trimmed()
        let comparator = sort.option.compare

        return items
            .filter(sort.filter)
            .filter {
                guard !query.isEmpty else { return true }
                return $0.title.localizedCaseInsensitiveContains(query)
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
            let titles: [Artist.ID: String] = await Dictionary(
                uniqueKeysWithValues: self.items.map { item in
                    (item.id, item.title)
                }
            )

            await MainActor.run {
                self.alternateTitles = titles
            }
        }
    }
}
