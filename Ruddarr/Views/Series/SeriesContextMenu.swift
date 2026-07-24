import SwiftUI
import TelemetryDeck

struct SeriesContextMenu: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Group {
            SeriesLinks(series: series)

            if series.exists && series.monitored {
                Divider()

                Button("Search Monitored", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard await instance.series.command(.seriesSearch(series.id)) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.seriesSearchDispatched)
    }
}
