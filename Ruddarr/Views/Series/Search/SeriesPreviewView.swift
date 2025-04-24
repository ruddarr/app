import SwiftUI
import TelemetryDeck

struct SeriesPreviewView: View {
    @State var series: Series

    @State private var presentingForm: Bool = false

    @EnvironmentObject var settings: AppSettings

    @Environment(SonarrInstance.self) private var instance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @AppStorage("seriesSort", store: dependencies.store) var seriesSort: SeriesSort = .init()
    @AppStorage("seriesDefaults", store: dependencies.store) var seriesDefaults: SeriesDefaults = .init()

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .viewPadding(.horizontal)
                .environmentObject(settings)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                SeriesForm(series: $series)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
                    #if os(macOS)
                        .padding(.all)
                    #else
                        .padding(.top, -25)
                    #endif
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
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
        ToolbarItem(placement: .cancellationAction) {
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
            }
            .disabled(presentingForm)
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.series.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Add Series") {
                    Task {
                        await addSeries()
                    }
                }
            }
        }
    }

    func addSeries() async {
        seriesDefaults = .init(from: series)

        guard await instance.series.add(series) else {
            leaveBreadcrumb(.error, category: "view.series.preview", message: "Failed to add series", data: ["error": instance.series.error ?? ""])

            return
        }

        guard let addedSeries = instance.series.byTvdbId(series.tvdbId) else {
            fatalError("Failed to locate added series by TVDB id")
        }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        presentingForm = false
        seriesSort.filter = .all

        let seriesPath = SeriesPath.series(addedSeries.id)
        dependencies.router.seriesPath.removeLast()
        try? await Task.sleep(for: .milliseconds(50))
        dependencies.router.seriesPath.append(seriesPath)

        TelemetryDeck.signal("seriesAdded")
        maybeAskForReview()
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series.first(where: { $0.tvdbId == 736_308 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.preview(
            try? JSONEncoder().encode(item)
        )
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
