import SwiftUI
import TelemetryDeck

struct SeriesContextMenu: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Group {
            SeriesLinks(series: series)

            Divider()

            if series.monitored {
                Button("Search Monitored", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard var status = await instance.series.command(.seriesSearch(series.id)) else {
            return
        }

        status.subject = series.title
        Commands.shared.track(status)

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.seriesSearchDispatched)
    }
}
