import SwiftUI
import TelemetryClient

struct SeriesPreviewView: View {
    @State var series: Series

    @State private var presentingForm: Bool = false

    @Environment(SonarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                SeriesForm(series: $series)
                    .padding(.top, -25)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
            }
            .presentationDetents([.medium])
        }
        .alert(
            isPresented: instance.series.errorBinding,
            error: instance.series.error
        ) { _ in
            Button("OK") { instance.series.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
                presentingForm = false
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Series") {
                presentingForm = true
            }.id(UUID())
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.series.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Done") {
                    Task {
                        await addSeries()
                    }
                }
            }
        }
    }

    @MainActor
    func addSeries() async {
        guard await instance.series.add(series) else {
            leaveBreadcrumb(.error, category: "view.series.preview", message: "Failed to add series", data: ["error": instance.series.error ?? ""])

            return
        }

        guard let addedSeries = instance.series.byTvdbId(series.tvdbId) else {
            fatalError("Failed to locate added series by tvdbId")
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        instance.lookup.reset()
        presentingForm = false

        let seriesPath = SeriesView.Path.series(addedSeries.id)

        dependencies.router.seriesPath.removeLast(dependencies.router.seriesPath.count)
        dependencies.router.seriesPath.append(seriesPath)

        TelemetryManager.send("seriesAdded")
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series.first(where: { $0.tvdbId == 736_308 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesView.Path.preview(
            try? JSONEncoder().encode(item)
        )
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
