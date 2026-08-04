import SwiftUI
import Sentry

struct SeriesPreviewView: View {
    @State var series: Series

    @State private var presentingForm: Bool = false

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @AppStorage("seriesDefaults", store: dependencies.store) var seriesDefaults: SeriesDefaults = .init()

    var body: some View {
        ScrollView {
            SeriesDetails(series: $series)
                .padding(.top)
                .scenePadding(.horizontal)
                .environment(settings)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .sensoryAlert(
            isPresented: instance.series.errorBinding,
            error: instance.series.error
        ) { _ in
            Button("OK") { instance.series.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .tint(nil)
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                SeriesForm(series: $series)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
                    #if os(iOS)
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
                    .hideIconOnMac()
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
            .hideIconOnMac()
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
                    ButtonProgressView()
                } else {
                    Label("Add Series", systemImage: "checkmark")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!instance.series.isWorking)
            .disabled(instance.series.isWorking || instance.rootFolders.isEmpty || instance.qualityProfiles.isEmpty)
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

        let seriesPath = SeriesPath.series(addedSeries.id)

        if !dependencies.router.seriesPath.isEmpty {
            dependencies.router.seriesPath.removeLast()
        }

        try? await Task.sleep(for: .milliseconds(50))
        dependencies.router.seriesPath.append(seriesPath)

        Telemetry.record(.seriesAdded, attributes: [
            "tmdb": series.tmdbId ?? 0,
            "imdb": series.imdbId ?? 0,
        ])

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
