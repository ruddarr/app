import SwiftUI

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(AppSettings.self) private var settings
    @Environment(RadarrInstance.self) private var instance
    @Environment(\.presentInstanceWeb) private var presentInstanceWeb

    var body: some View {
        Group {
            MovieLinks(movie: movie)

            if movie.exists, let config = settings.instanceById(instance.id) {
                Button("Open in \(config.label)", systemImage: "safari") {
                    presentInstanceWeb.wrappedValue = InstanceWebPresentation(
                        instance: config,
                        path: "movie/\(movie.tmdbId)"
                    )
                }
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
