import SwiftUI

struct MovieContextMenu: View {
    var movie: Movie

    @Environment(RadarrInstance.self) private var instance
    @Environment(\.deleteMovie) private var deleteMovie

    var body: some View {
        Group {
            MovieLinks(movie: movie)

            if movie.exists {
                Divider()

                Button("Automatic Search", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }

                Button(
                    movie.monitored ? "Unmonitor" : "Monitor",
                    systemImage: movie.monitored ? "bookmark.slash" : "bookmark"
                ) {
                    Task { await toggleMonitor() }
                }

                if let deleteMovie {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteMovie.wrappedValue = movie
                    }.tint(.red)
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

    func toggleMonitor() async {
        guard var item: Movie = instance.movies.byId(movie.id) else {
            return
        }

        item.monitored = !movie.monitored

        guard await instance.movies.update(item) else {
            return
        }

        _ = await instance.movies.get(item)

        dependencies.toast.show(item.monitored ? .monitored : .unmonitored)
    }
}
