import SwiftUI
import TelemetryClient

struct SeriesDetailView: View {
    @Binding var series: Series

    @Environment(SonarrInstance.self) private var instance

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            SeriesDetails(series: series)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .refreshable {
            await refresh()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
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
            Button("Delete Series", role: .destructive) {
                Task { await deleteSeries(series) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete the TV series and permanently erase its folder and its contents.")
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                Circle()
                    .fill(.secondarySystemBackground)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11, weight: .bold))
                            .symbolVariant(series.monitored ? .fill : .none)
                            .foregroundStyle(.tint)
                    }
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.series.isWorking)
            .id(UUID())
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                    editAction
                }

                Section {
                    searchMonitored
                }

                openInLinks
                deleteSeriesButton
            } label: {
                actionMenuIcon
            }
            .id(UUID())
        }
    }

    var actionMenuIcon: some View {
        Circle()
            .fill(.secondarySystemBackground)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "ellipsis")
                    .symbolVariant(.fill)
                    .font(.system(size: 12, weight: .bold))
                    .symbolVariant(series.monitored ? .fill : .none)
                    .foregroundStyle(.tint)
            }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        NavigationLink(
            value: SeriesView.Path.edit(series.id)
        ) {
            Label("Edit", systemImage: "pencil")
        }
    }

    var searchMonitored: some View {
        Button("Search Monitored", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
    }

    var openInLinks: some View {
        Section {
            SeriesContextMenu(series: series)
        }
    }

    var deleteSeriesButton: some View {
        Section {
            Button("Delete", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }
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
    func refresh() async {
        guard await instance.series.command(series, command: .refresh) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.series.fetch() }
        }
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(series, command: .searchMonitored) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        // TODO: do we need more details for all of these?
        TelemetryManager.send("automaticSearchDispatched")
    }

    @MainActor
    func deleteSeries(_ series: Series) async {
        _ = await instance.series.delete(series)

        dependencies.router.seriesPath.removeLast()
        dependencies.toast.show(.seriesDeleted)
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 2 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesView.Path.series(item.id)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
