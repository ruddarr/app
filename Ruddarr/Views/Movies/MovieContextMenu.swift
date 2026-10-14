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

                if let deleteMovie {
                    Button(
                        movie.monitored ? "Unmonitor" : "Monitor",
                        systemImage: movie.monitored ? "bookmark.slash" : "bookmark"
                    ) {
                        Task { await toggleMonitor() }
                    }

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
        var item = movie
        item.monitored.toggle()

        guard await instance.movies.update(item) else {
            return
        }

        if let index = instance.movies.items.firstIndex(where: { $0.id == item.id }) {
            instance.movies.items[index].monitored = item.monitored
        }

        dependencies.toast.show(item.monitored ? .monitored : .unmonitored)
    }
}
