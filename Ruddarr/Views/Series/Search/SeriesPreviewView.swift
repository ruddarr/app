import SwiftUI
import TelemetryDeck

struct SeriesPreviewView: View {
    @State var series: Series

    @State private var presentingForm: Bool = false
    @State private var isHydrating: Bool = false

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
        .alert(
            isPresented: instance.series.errorBinding,
            error: instance.series.error
        ) { _ in
            Button("OK") { instance.series.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .tint(nil)
        .task {
            await hydrateFromSonarrIfNeeded()
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
            .presentationBackground(.sheetBackground)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presentingForm = false
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.primary)
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Series", systemImage: "plus") {
                presentingForm = true
            }
            .buttonStyle(.glassProminent)
            .disabled(presentingForm)
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await addSeries()
                }
            } label: {
                if instance.series.isWorking {
                    ProgressView().tint(nil)
                } else {
                    Label("Add Series", systemImage: "checkmark")
                }
            }
            .prominentGlassButtonStyle(!instance.series.isWorking)
            .disabled(instance.series.isWorking)
        }
    }

    /// Hydrate only when the preview is opened to avoid bulk API calls
    func hydrateFromSonarrIfNeeded() async {
        guard !instance.isVoid,
              !isHydrating,
              !series.exists,
              let tmdbId = series.tmdbId else { return }

        isHydrating = true
        defer { isHydrating = false }

        do {
            let results = try await dependencies.api.lookupSeries(instance.lookup.instance, "tmdbid:\(tmdbId)")
            if let enriched = results.first(where: { $0.tmdbId == tmdbId }) {
                series = enriched
            }
        } catch {
            leaveBreadcrumb(.error, category: "series.preview", message: "Hydrate failed", data: ["error": error.localizedDescription])
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

        if !dependencies.router.seriesPath.isEmpty {
            dependencies.router.seriesPath.removeLast()
        }

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
