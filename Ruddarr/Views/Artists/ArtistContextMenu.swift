import SwiftUI

struct ArtistContextMenu: View {
    var artist: Artist

    @Environment(LidarrInstance.self) private var instance

    var body: some View {
        Group {
            if artist.monitored {
                Button("Search Monitored", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }

                Divider()
            }
            ArtistLinks(artist: artist)
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard await instance.artists.command(.artistSearch(artist.id)) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.artistSearchDispatched)
    }
}
