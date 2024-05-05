import SwiftUI

struct SeriesEditView: View {
    @Binding var series: Series

    init(series: Binding<Series>) {
        self._series = series
        self._unmodifiedSeries = State(initialValue: series.wrappedValue)
    }

    @Environment(SonarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmation: Bool = false
    @State private var savedChanges: Bool = false
    @State private var unmodifiedSeries: Series

    var body: some View {
        SeriesForm(series: $series)
            .padding(.top, -20)
            .navigationTitle(series.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarSaveButton
            }
            .onDisappear {
                if !savedChanges {
                    undoSeriesChanges()
                }
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
                "Move the series files to \"\(series.rootFolderPath!)\"?",
                isPresented: $showConfirmation
            ) {
                Button("Move Files", role: .destructive) {
                    Task { await updateSeries(moveFiles: true) }
                }
                Button("No") {
                    Task { await updateSeries() }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.series.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Save") {
                    if series.exists && hasRootFolderChanged() {
                        showConfirmation = true
                    } else {
                        Task { await updateSeries() }
                    }
                }
                .id(UUID())
            }
        }
    }

    func hasRootFolderChanged() -> Bool {
        series.rootFolderPath?.untrailingSlashIt != unmodifiedSeries.rootFolderPath?.untrailingSlashIt
    }

    @MainActor
    func updateSeries(moveFiles: Bool = false) async {
        _ = await instance.series.update(series, moveFiles: moveFiles)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        savedChanges = true

        dismiss()
    }

    // TODO: needs work
    func undoSeriesChanges() {
        // series.monitored = unmodifiedMovie.monitored
        // series.minimumAvailability = unmodifiedMovie.minimumAvailability
        // series.qualityProfileId = unmodifiedMovie.qualityProfileId
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    dependencies.router.selectedTab = .series
    dependencies.router.seriesPath.append(SeriesView.Path.series(item.id))
    dependencies.router.seriesPath.append(SeriesView.Path.edit(item.id))

    return ContentView()
        .withAppState()
        .withSonarrInstance(series: series)
}
