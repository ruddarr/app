import SwiftUI
import TelemetryDeck

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        Group {
            MovieLinks(movie: movie)

            Divider()

            Button("Automatic Search", systemImage: "magnifyingglass") {
                Task { await dispatchSearch() }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard var status = await instance.movies.command(.search([movie.id])) else {
            return
        }

        status.subject = movie.title
        Commands.shared.track(status)

        dependencies.toast.show(.movieSearchQueued)

        Telemetry.record(.movieSearchDispatched)
    }
}
