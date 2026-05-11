import os
import SwiftUI

@MainActor
@Observable
class ArtistFiles {
    var instance: Instance

    var items: [TrackFile] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func fetched(_ artist: Artist) -> Bool {
        items.contains { $0.artistId == artist.id }
    }
}
