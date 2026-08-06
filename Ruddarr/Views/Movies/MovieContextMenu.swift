import SwiftUI

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(AppSettings.self) private var settings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        Group {
            MovieLinks(movie: movie)

            if movie.exists, let config = settings.instanceById(instance.id) {
                InstanceWebLink(instance: config, path: movie.webPath)
            }

            if movie.exists {
                Divider()

                Button("Automatic Search", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard await instance.movies.command(.search([movie.id])) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        Telemetry.record(.movieSearchDispatched)
    }
}
