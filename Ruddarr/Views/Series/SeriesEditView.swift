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
            .safeNavigationBarTitleDisplayMode(.inline)
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
                "Move the series files to \"\(series.rootFolderPath ?? "")\"?",
                isPresented: $showConfirmation
            ) {
                Button("Move Files", role: .destructive) {
                    Task { await updateSeries(moveFiles: true) }
                }
                Button("No", role: .confirm) {
                    Task { await updateSeries() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .tint(nil)
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                if series.exists && hasRootFolderChanged() {
                    showConfirmation = true
                } else {
                    Task { await updateSeries() }
                }
            } label: {
                if instance.series.isWorking {
                    ProgressView().tint(nil)
                } else {
                    #if os(macOS)
                        Text("Save")
                    #else
                        Label("Save", systemImage: "checkmark")
                    #endif
                }
            }
            .prominentGlassButtonStyle(!instance.series.isWorking)
        }
    }

    func hasRootFolderChanged() -> Bool {
        series.rootFolderPath?.untrailingSlashIt != unmodifiedSeries.rootFolderPath?.untrailingSlashIt
    }

    func updateSeries(moveFiles: Bool = false) async {
        _ = await instance.series.update(series, moveFiles: moveFiles)

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        savedChanges = true

        dismiss()
    }

    func undoSeriesChanges() {
        series.monitored = unmodifiedSeries.monitored
        series.qualityProfileId = unmodifiedSeries.qualityProfileId
        series.seriesType = unmodifiedSeries.seriesType
        series.seasonFolder = unmodifiedSeries.seasonFolder
        series.rootFolderPath = unmodifiedSeries.rootFolderPath
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    dependencies.router.selectedTab = .series
    dependencies.router.seriesPath.append(SeriesPath.series(item.id))
    dependencies.router.seriesPath.append(SeriesPath.edit(item.id))

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
