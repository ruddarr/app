import SwiftUI

struct SeriesContextMenu: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance
    @Environment(\.deleteSeries) private var deleteSeries

    var body: some View {
        Group {
            SeriesLinks(series: series)

            if series.exists {
                if series.monitored || deleteSeries != nil {
                    Divider()
                }

                if series.monitored {
                    Button("Search Monitored", systemImage: "magnifyingglass") {
                        Task { await dispatchSearch() }
                    }
                }

                if let deleteSeries {
                    Button(
                        series.monitored ? "Unmonitor" : "Monitor",
                        systemImage: series.monitored ? "bookmark.slash" : "bookmark"
                    ) {
                        Task { await toggleMonitor() }
                    }

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteSeries.wrappedValue = series
                    }.tint(.red)
                }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard await instance.series.command(.seriesSearch(series.id)) else {
            instance.series.error = nil
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.seriesSearchDispatched)
    }

    func toggleMonitor() async {
        var item = series
        item.monitored.toggle()

        guard await instance.series.update(item) else {
            instance.series.error = nil
            return
        }

        if let index = instance.series.items.firstIndex(where: { $0.id == item.id }) {
            instance.series.items[index].monitored = item.monitored
        }

        dependencies.toast.show(item.monitored ? .monitored : .unmonitored)
    }
}
