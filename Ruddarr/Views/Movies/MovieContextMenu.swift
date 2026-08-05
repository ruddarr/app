import SwiftUI

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    #if os(iOS)
        @Environment(AppSettings.self) private var settings
        @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        Group {
            MovieLinks(movie: movie)

            #if os(iOS)
                if movie.exists, let config = settings.instanceById(instance.id) {
                    Button("Open in \(config.label)", systemImage: "safari") {
                        Task {
                            if let url = await config.webURL(path: "movie/\(movie.tmdbId)") {
                                openURL(url, prefersInApp: true)
                            }
                        }
                    }
                }
            #endif

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
