import os
import SwiftUI

@MainActor
@Observable
class AlbumModel {
    var instance: Instance

    var items: [Album] = []
    var itemsCount: Int = 0

    var cachedItems: [Album] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false
    var isFetching: Bool = false
    var isMonitoring: Album.ID = 0

    private var alternateTitles: [Album.ID: String] = [:]
    private var sortAndFilterTask: Task<Void, Never>?

    enum Operation {
        case fetch(Artist)
        case get(Album)
        case add(Album)
        case push(Album)
//        case update(Album, Bool)
        case delete(Album, Bool, Bool)
        case download(String, Int, Int?)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func updateCachedItems(_ sort: AlbumSort, _ searchQuery: String) {
        sortAndFilterTask?.cancel()

        sortAndFilterTask = Task { @MainActor in
            let items = self.items
            let alternateTitles = self.alternateTitles

            cachedItems = await Task.detached(priority: .userInitiated) {
                Self.filterAndSortItems(items, alternateTitles, sort, searchQuery)
            }.result.get()
        }
    }

    func byId(_ id: Album.ID) -> Album? {
        self.items.first(where: { $0.id == id })
    }

    func byId(_ id: Album.ID) -> Binding<Album> {
        Binding(
            get: { [weak self] in
                guard let self, let index = self.items.firstIndex(where: { $0.id == id }) else {
                    // item will be removed while still displayed briefly before navigation occurs
                    return .void
                }

                return self.items[index]
            },
            set: { [weak self] newValue in
                guard let index = self?.items.firstIndex(where: { $0.id == id }) else {
                    self?.items.append(newValue)
                    return
                }

                self?.items[index] = newValue
            }
        )
    }

    func byArtistId(_ artistId: Artist.ID) -> [Album] {
        self.items.filter { $0.artistId == artistId }
    }

    func byArtistId(_ id: Artist.ID) -> Binding<[Album]> {
        Binding(
            get: { [weak self] in
                guard let self else {
                    // item will be removed while still displayed briefly before navigation occurs
                    return []
                }

                return self.items.filter { $0.artistId == id }
            },
            set: { [weak self] newValue in
                guard let self else { return }
                // Replace all albums for this artist with the new value
                self.items.removeAll(where: { $0.artistId == id })
                self.items.append(contentsOf: newValue)
            }
        )
    }

    func byForeignAlbumId(_ foreignId: String) -> Album? {
        self.items.first(where: { $0.foreignAlbumId == foreignId })
    }

//    func fetch(_ artist: Artist) async -> Bool {
//        await request(.fetch(artist))
//    }

    func get(_ album: Album) async -> Bool {
        await request(.get(album))
    }

    func add(_ album: Album) async -> Bool {
        await request(.add(album))
    }

    func push(_ album: Album) async -> Bool {
        await request(.push(album))
    }

    func delete(_ album: Album, addExclusion: Bool, deleteFiles: Bool) async -> Bool {
        await request(.delete(album, addExclusion, deleteFiles))
    }

    func download(guid: String, indexerId: Int, albumId: Int?) async -> Bool {
        await request(.download(guid, indexerId, albumId))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

    func fetched(_ artist: Artist) -> Bool {
        items.contains { $0.artistId == artist.id }
    }

    func maybeFetch(_ artist: Artist) async {
        let force = abs(artist.added.timeIntervalSinceNow) < 30

        if !fetched(artist) || force {
            await fetch(artist)
        }
    }

    func fetch(_ artist: Artist) async {
        error = nil
        isFetching = true

        if let album = items.first,
           album.artistId != artist.id,
           album.instanceId != artist.instanceId
        {
            items = []
        }

        do {
            let newItems = try await dependencies.api.fetchAlbums(artist.id, instance)

            if items != newItems {
                items = newItems
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.episodes", message: "Album fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
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

            leaveBreadcrumb(.error, category: "Albums", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false

        return error == nil
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch(let artist):
            items = try await dependencies.api.fetchAlbums(artist.id, instance)
            itemsCount = items.count
            computeAlternateTitles()
            await Spotlight(instance.id).index(items, delay: .seconds(5))

            leaveBreadcrumb(.info, category: "Albums", message: "Fetched Albums", data: ["count": items.count])

        case .get(let album):
            if let index = items.firstIndex(where: { $0.id == album.id }) {
                let item = try await dependencies.api.getAlbum(album, instance)

                if items[index] != item {
                    items[index] = item
                }
            }

        case .add(let album):
            items.append(try await dependencies.api.addAlbum(album, instance))

        case .push(let album):
            _ = try await dependencies.api.pushAlbum(album, instance)

        case .delete(let album, let addExclusion, let deleteFiles):
            _ = try await dependencies.api.deleteAlbum(album, addExclusion, deleteFiles, instance)
            items.removeAll(where: { $0.id == album.id })

        case .download(let guid, let indexerId, let artistId):
            let payload = DownloadReleaseCommand(guid: guid, indexerId: indexerId, artistId: artistId)
            _ = try await dependencies.api.downloadRelease(payload, instance)

        case .command(let command):
            _ = try await dependencies.api.command(command, instance)
        }
    }

    nonisolated private static func filterAndSortItems(
        _ items: [Album],
        _ alternateTitles: [Album.ID: String],
        _ sort: AlbumSort,
        _ searchQuery: String
    ) -> [Album] {
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
