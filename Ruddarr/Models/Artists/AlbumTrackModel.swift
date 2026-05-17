import os
import SwiftUI

@MainActor
@Observable
class AlbumTrackModel {
    var instance: Instance

    var items: [AlbumTrack] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func byId(_ id: AlbumTrack.ID) -> AlbumTrack? {
        items.first { $0.id == id }
    }

    func byAlbumId(_ album: Album.ID) -> [AlbumTrack] {
        items.filter { $0.albumId == album }
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

        if let track = items.first,
           track.artistId != artist.id,
           track.instanceId != artist.instanceId
        {
            items = []
        }

        do {
            let newItems = try await dependencies.api.fetchArtistTracks(artist.id, instance)

            if items != newItems {
                items = newItems
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "artist.tracks", message: "Tracks fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }
}
