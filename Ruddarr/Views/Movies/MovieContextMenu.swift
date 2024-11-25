import SwiftUI
import TelemetryDeck

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        MovieLinks(movie: movie)

        Divider()

        Button("Automatic Search", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
    }

    func dispatchSearch() async {
        guard await instance.movies.command(.search([movie.id])) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "movie"])
    }
}
