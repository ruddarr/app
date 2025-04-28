import SwiftUI
import TelemetryDeck

struct SeriesDetailView: View {
    @Binding var series: Series

    @EnvironmentObject var settings: AppSettings

    @Environment(\.deviceType) private var deviceType
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SonarrInstance.self) private var instance

    @State private var showEditForm = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .viewPadding(.horizontal)
                .environmentObject(settings)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .onChange(of: scenePhase, handleScenePhaseChange)
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
        .sheet(isPresented: $showDeleteConfirmation) {
            MediaDeleteSheet(label: "Delete Series") { exclude, delete in
                Task {
                    await deleteSeries(exclude: exclude, delete: delete)
                    showDeleteConfirmation = false
                }
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .fraction(0.33) : .medium])
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
            #if os(macOS)
                .sheet(isPresented: $showEditForm) {
                    SeriesEditView(series: $series)
                        .environment(instance)
                        .padding(.top)
                        .padding(.all)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showEditForm = false }
                            }
                        }
                }
            #endif
        }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        #if os(macOS)
            Button("Edit") {
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
        }
    }
}

extension SeriesDetailView {
    func toggleMonitor() async {
        series.monitored.toggle()

        guard await instance.series.update(series) else {
            return
        }

        dependencies.toast.show(series.monitored ? .monitored : .unmonitored)
    }

    func reload() async {
        _ = await instance.series.get(series)
        await instance.episodes.fetch(series)
        await instance.files.fetch(series)
    }

    func refresh() async {
        guard await instance.series.command(.refreshSeries(series.id)) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.series.get(series) }
        }
    }

    func handleScenePhaseChange(_ from: ScenePhase, _ to: ScenePhase) {
        if from == .background, to == .inactive {
            Task { await reload() }
        }
    }

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

    func deleteSeries(exclude: Bool, delete: Bool) async {
        _ = await instance.series.delete(series, addExclusion: exclude, deleteFiles: delete)

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
