import SwiftUI

struct SeriesContextMenu: View {
    var series: Series

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            SeriesLinks(series: series)

            if series.exists, let config = settings.instanceById(instance.id) {
                Button("Open in \(config.label)", systemImage: "safari") {
                    Task {
                        if let url = await config.webURL(path: webPath) {
                            openURL(url, prefersInApp: true)
                        }
                    }
                }
            }

            if series.exists && series.monitored {
                Divider()

                Button("Search Monitored", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }
            }
        }.tint(.primary)
    }

    var webPath: String {
        guard let slug = series.titleSlug, !slug.isEmpty else { return "" }
        return "series/\(slug)"
    }

    func dispatchSearch() async {
        guard await instance.series.command(.seriesSearch(series.id)) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.seriesSearchDispatched)
    }
}
