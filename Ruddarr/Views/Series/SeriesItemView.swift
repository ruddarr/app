import SwiftUI
import TelemetryDeck

struct SeriesDetailView: View {
    @Binding var series: Series

    @Environment(SonarrInstance.self) private var instance

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .onAppear {
            maybeReloadRepeatedly()
        }
        .task {
            await instance.episodes.maybeFetch(series)
            await instance.files.maybeFetch(series)
        }
        .alert(
            isPresented: instance.series.errorBinding,
            error: instance.series.error
        ) { _ in
            Button("OK") { instance.series.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete Series", role: .destructive) { Task { await deleteSeries() } }
            Button("Delete and Exclude", role: .destructive) { Task { await deleteSeries(exclude: true) } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the series and permanently erase its folder and its contents.")
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: $series.monitored)
            }
            .allowsHitTesting(!instance.series.isWorking)
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                    searchMonitored
                }

                Section {
                    SeriesLinks(series: series)
                }

                Section {
                    editAction
                    deleteSeriesButton
                }
            } label: {
                ToolbarActionButton()
            }
        }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        NavigationLink(
            value: SeriesPath.edit(series.id)
        ) {
            Label("Edit", systemImage: "pencil")
        }
    }

    var searchMonitored: some View {
        Button("Search Monitored", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
        .disabled(!series.monitored)
    }

    var deleteSeriesButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }
    }
}

extension SeriesDetailView {
    @MainActor
    func toggleMonitor() async {
        series.monitored.toggle()

        guard await instance.series.update(series) else {
            return
        }

        dependencies.toast.show(series.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func reload() async {
        _ = await instance.series.get(series)
        await instance.episodes.fetch(series)
        await instance.files.fetch(series)
    }

    @MainActor
    func refresh() async {
        guard await instance.series.command(.refreshSeries(series.id)) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.series.get(series) }
        }
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .seriesSearch(series.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "series"])
        maybeAskForReview()
    }

    @MainActor
    func deleteSeries(exclude: Bool = false) async {
        _ = await instance.series.delete(series, addExclusion: exclude)

        if !dependencies.router.seriesPath.isEmpty {
            dependencies.router.seriesPath.removeLast()
        }

        dependencies.toast.show(.seriesDeleted)
    }

    // This is an annoying "hack" because Sonarr takes a couple of seconds
    // after adding a new series before it updates its monitoring values.
    func maybeReloadRepeatedly() {
        if abs(series.added.timeIntervalSinceNow) > 15 {
            return
        }

        Task {
            for _ in 0..<6 {
                _ = await instance.series.get(series, silent: true)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.series(item.id)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
