import SwiftUI

struct SeriesContextMenu: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance
    @Environment(\.deleteSeries) private var deleteSeries

    var body: some View {
        Group {
            SeriesLinks(series: series)

            if series.exists {
                Divider()

                if series.monitored {
                    Button("Search Monitored", systemImage: "magnifyingglass") {
                        Task { await dispatchSearch() }
                    }
                }

                Button(
                    series.monitored ? "Unmonitor" : "Monitor",
                    systemImage: series.monitored ? "bookmark.slash" : "bookmark"
                ) {
                    Task { await toggleMonitor() }
                }

                if let deleteSeries {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteSeries.wrappedValue = series
                    }.tint(.red)
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

    func toggleMonitor() async {
        guard var item: Series = instance.series.byId(series.id) else {
            return
        }

        item.monitored = !series.monitored

        guard await instance.series.update(item) else {
            return
        }

        _ = await instance.series.get(item)

        dependencies.toast.show(item.monitored ? .monitored : .unmonitored)
    }
}
