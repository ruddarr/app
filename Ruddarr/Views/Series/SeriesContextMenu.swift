import SwiftUI
import TelemetryDeck

struct SeriesContextMenu: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        SeriesLinks(series: series)

        Divider()

        if series.monitored {
            Button("Search Monitored", systemImage: "magnifyingglass") {
                Task { await dispatchSearch() }
            }
        }
    }

    func dispatchSearch() async {
        guard await instance.series.command(.seriesSearch(series.id)) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "series"])
    }
}
