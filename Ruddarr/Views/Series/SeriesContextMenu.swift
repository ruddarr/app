import SwiftUI

struct SeriesContextMenu: View {
    var series: Series

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Group {
            SeriesLinks(series: series)

            if series.exists, let config = settings.instanceById(instance.id) {
                InstanceWebLink(instance: config, path: series.webPath)
            }

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
