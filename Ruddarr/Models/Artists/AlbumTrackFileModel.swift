import os
import SwiftUI

@MainActor
@Observable
class AlbumTrackFileModel {
    var instance: Instance

    var items: [AlbumTrackFile] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: AlbumTrackFile.ID) -> AlbumTrackFile? {
        self.items.first(where: { $0.id == id })
    }

    func byId(_ id: AlbumTrackFile.ID) -> Binding<AlbumTrackFile> {
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

    func byAlbumId(_ id: Album.ID) -> [AlbumTrackFile] {
        self.items.filter { $0.albumId == id }
    }

    func byAlbumId(_ id: Album.ID) -> Binding<[AlbumTrackFile]> {
        Binding(
            get: { [weak self] in
                guard let self else {
                    // item will be removed while still displayed briefly before navigation occurs
                    return []
                }

                return self.items.filter { $0.albumId == id }
            },
            set: { [weak self] newValue in
                guard let self else { return }
                // Replace all albums for this artist with the new value
                self.items.removeAll(where: { $0.albumId == id })
                self.items.append(contentsOf: newValue)
            }
        )
    }

    func byArtistId(_ id: Artist.ID) -> [AlbumTrackFile] {
        self.items.filter { $0.artistId == id }
    }

    func byArtistId(_ id: Artist.ID) -> Binding<[AlbumTrackFile]> {
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

        if let track = items.first, track.artistId != artist.id {
            items = []
        }

        do {
            let newItems = try await dependencies.api.fetchArtistTrackFiles(artist.id, instance)

            if items != newItems {
                items = newItems
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.tracks", message: "Artist files fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }

    func delete(_ track: AlbumTrackFile) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteTrackFile(track, instance)

            if let index = items.firstIndex(where: { $0.id == track.id }) {
                items.remove(at: index)
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.tracks", message: "Artist file deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

    func delete(_ tracks: [AlbumTrackFile]) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteTrackFiles(tracks, instance)

            let deleted = Set(tracks.map(\.id))
            items.removeAll { deleted.contains($0.id) }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.tracks", message: "Artist file deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

}
