import os
import SwiftUI

@MainActor
@Observable
class ArtistTracks {
    var instance: Instance

    var items: [AlbumTrack] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func fetched(_ artist: Artist) -> Bool {
        items.contains { $0.artistId == artist.id }
    }

    func maybeFetch(_ artist: Artist) async {
        guard !fetched(artist) else { return }
        await fetch(artist)
    }

    func fetch(_ artist: Artist) async {
        error = nil
        isFetching = true

        if let file = items.first, file.artistId != artist.id {
            items = []
        }

        do {
            let newItems = try await dependencies.api.fetchArtistFiles(artist.id, instance)

            if items != newItems {
                items = newItems
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.files", message: "Artist files fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }

    func delete(_ file: AlbumTrack) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteArtistFile(file, instance)

            if let index = items.firstIndex(where: { $0.id == file.id }) {
                items.remove(at: index)
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.files", message: "Artist file deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

    func delete(_ files: [AlbumTrack]) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteArtistFiles(files, instance)

            let deleted = Set(files.map(\.id))
            items.removeAll { deleted.contains($0.id) }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.files", message: "Artist file deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

}
