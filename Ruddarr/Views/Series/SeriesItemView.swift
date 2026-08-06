import SwiftUI

struct SeriesDetailView: View {
    @Binding var series: Series

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.deviceType) private var deviceType
    @Environment(\.inCalendarSheet) private var inCalendarSheet

    @State private var showEditForm = false
    @State private var showDeleteConfirmation = false
    @State private var togglingMonitor = false

    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .scenePadding(.horizontal)
                .environment(settings)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            CalendarSheetAwareToolbar(deeplink: deeplink)
            toolbarMonitorButton
            toolbarMenu
        }
        .onAppear {
            maybeReloadRepeatedly()
        }
        .onDisappear {
            reloadTask?.cancel()
        }
        .task {
            await instance.episodes.maybeFetch(series)
        }
        .onBecomeActive {
            await reload()
        }
        .sensoryAlert(
            isPresented: instance.series.errorBinding,
            error: instance.series.error
        ) { _ in
            Button("OK") { instance.series.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .sheet(isPresented: $showDeleteConfirmation) {
            MediaDeleteSheet(label: "Delete Series") { exclude, delete in
                Task {
                    await deleteSeries(exclude: exclude, delete: delete)
                    showDeleteConfirmation = false
                }
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .fraction(0.33) : .medium])
            .presentationBackground(.sheetBackground)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: series.monitored, loading: togglingMonitor)
            }
            .allowsHitTesting(!togglingMonitor)
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

                    if inCalendarSheet == nil {
                        deleteSeriesButton
                    }
                }
            } label: {
                ToolbarActionButton()
            }
            .tint(.primary)
            .menuIndicator(.hidden)
            #if os(macOS)
                .sheet(isPresented: $showEditForm) {
                    SeriesEditView(series: $series)
                        .environment(instance)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showEditForm = false }
                            }
                        }
                }
            #endif
        }
    }

    var deeplink: URL? {
        guard let instanceId = series.instanceId else { return nil }
        return QuickActions.Deeplink.openSeries(series.id, instanceId.uuidString).url
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        #if os(macOS)
            Button("Edit", systemImage: "pencil") {
                showEditForm = true
            }
        #else
            NavigationLink(
                value: SeriesPath.edit(series.id)
            ) {
                Label("Edit", systemImage: "pencil")
            }
        #endif
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
        }.tint(.red)
    }
}

extension SeriesDetailView {
    func toggleMonitor() async {
        let original = series.monitored
        series.monitored = !original

        togglingMonitor = true
        defer { togglingMonitor = false }

        guard await instance.series.update(series) else {
            if series.monitored == !original {
                series.monitored = original
            }

            return
        }

        dependencies.toast.show(series.monitored ? .monitored : .unmonitored)
    }

    func reload() async {
        _ = await instance.series.get(series)
        await instance.episodes.fetch(series)
    }

    func refresh() async {
        guard await instance.series.command(.refreshSeries(series.id)) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        Task {
            try? await Task.sleep(for: .seconds(3))
            _ = await instance.series.get(series)
        }
    }

    func dispatchSearch() async {
        guard await instance.series.command(
            .seriesSearch(series.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.seriesSearchDispatched)
        maybeAskForReview()
    }

    func deleteSeries(exclude: Bool, delete: Bool) async {
        _ = await instance.series.delete(series, addExclusion: exclude, deleteFiles: delete)

        if let inCalendarSheet {
            inCalendarSheet.dismiss()
        } else if !dependencies.router.seriesPath.isEmpty {
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

        reloadTask?.cancel()

        reloadTask = Task {
            for _ in 0..<6 {
                if Task.isCancelled { return }

                _ = await instance.series.get(series, silent: true)
                try? await Task.sleep(for: .seconds(1))
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
