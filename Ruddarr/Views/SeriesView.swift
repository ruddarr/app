import SwiftUI
import Combine

struct SeriesView: View {
    @AppStorage("seriesSort", store: dependencies.store) var sort: SeriesSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: API.Error?
    @State private var alertPresented = false

    @Environment(\.scenePhase) private var scenePhase

    // TODO: WIP
    enum Path: Hashable {
        case search(String = "")
        // case preview(Data?)
        case series(Series.ID)
        case edit(Series.ID)
        case releases(Series.ID)
        // case metadata(Movie.ID)
        case season(Series.ID, Season.ID)
    }

    var body: some View {
        // swiftlint:disable closure_body_length
        NavigationStack(path: dependencies.$router.seriesPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Sonarr")
                } else {
                    ScrollView {
                        seriesItemGrid
                            .padding(.top, searchPresented ? 10 : 0)
                            .viewPadding(.horizontal)
                    }
                    .task {
                        guard !instance.isVoid else { return }
                        await fetchSeriesWithAlert(ignoreOffline: true)
                    }
                    .refreshable {
                        await fetchSeriesWithAlert()
                    }
                    .onChange(of: scenePhase, handleScenePhaseChange)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .search(let query):
                    EmptyView() // TODO: WIP
                case .series(let id):
                    if let series = instance.series.byId(id).unwrapped {
                        SeriesDetailView(series: series)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .edit(let id):
                    EmptyView() // TODO: WIP
                case .releases(let id):
                    EmptyView() // TODO: WIP
                case .season(let id, let season):
                    if let series = instance.series.byId(id).unwrapped {
                        SeasonView(series: series, seasonId: season)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                }
            }
            .onAppear {
                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if instance.isVoid, let first = settings.sonarrInstances.first {
                    settings.sonarrInstanceId = first.id
                    changeInstance()
                }

                // if a deeplink set an instance, try to switch to it
                if let id = dependencies.router.switchToSonarrInstance, id != instance.id {
                    dependencies.router.switchToSonarrInstance = nil
                    settings.sonarrInstanceId = id
                    changeInstance()
                }

                dependencies.quickActions.pending()
            }
            .onReceive(dependencies.quickActions.seriesPublisher, perform: navigateToSeries)
            .toolbar {
                toolbarViewOptions

                if settings.sonarrInstances.count > 1 {
                    toolbarInstancePicker
                }

                toolbarSearchButton
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .onChange(of: [sort, searchQuery] as [AnyHashable]) {
                updateDisplayedSeries()
            }
            .alert(isPresented: $alertPresented, error: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if hasNoSearchResults {
                    NoSeriesSearchResults(query: $searchQuery)
                } else if isLoadingSeries {
                    Loading()
                } else if hasNoMatchingResults {
                    NoMatchingSeries()
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
        // swiftlint:enable closure_body_length
    }

    var notConnectedToInternet: Bool {
        if !instance.series.cachedItems.isEmpty { return false }
        if case .notConnectedToInternet = error { return true }
        return false
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && !instance.isVoid && instance.series.cachedItems.isEmpty
    }

    var hasNoMatchingResults: Bool {
        instance.series.cachedItems.isEmpty && instance.series.itemsCount > 0
    }

    var isLoadingSeries: Bool {
        instance.series.isWorking && instance.series.cachedItems.isEmpty
    }

    var initialLoadingFailed: Bool {
        guard instance.series.itemsCount == 0 else { return false }
        return instance.series.error != nil
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("Connection Failure", systemImage: "exclamationmark.triangle")
        } description: {
            Text(instance.series.error?.recoverySuggestionFallback ?? "")
        } actions: {
            Button("Retry") {
                Task { await fetchSeriesWithAlert(ignoreOffline: true) }
            }
        }
    }

    @ViewBuilder
    var seriesItemGrid: some View {
        let gridItemLayout = MovieGridItem.gridItemLayout()
        let gridItemSpacing = MovieGridItem.gridItemSpacing()

        LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
            ForEach(instance.series.cachedItems) { series in
                NavigationLink(value: Path.series(series.id)) {
                    SeriesGridItem(series: series)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func updateDisplayedSeries() {
        instance.series.sortAndFilterItems(sort, searchQuery)
    }

    func fetchSeriesWithMetadata() {
        Task { @MainActor in
            _ = await instance.series.fetch()
            updateDisplayedSeries()

            let lastMetadataFetch = "instanceMetadataFetch:\(instance.id)"
            let cacheInSeconds: Double = instance.isLarge ? 300 : 30

            if Occurrence.since(lastMetadataFetch) > cacheInSeconds {
                if let model = await instance.fetchMetadata() {
                    settings.saveInstance(model)
                    Occurrence.occurred(lastMetadataFetch)
                }
            }
        }
    }

    @MainActor
    func fetchSeriesWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.series.fetch()
        updateDisplayedSeries()

        if let apiError = instance.series.error {
            error = apiError

            if case .notConnectedToInternet = apiError, ignoreOffline {
                return
            }

            alertPresented = true
        }
    }

    func handleScenePhaseChange(_ oldPhase: ScenePhase, _ phase: ScenePhase) {
        guard dependencies.router.seriesPath.isEmpty else {
            return
        }

        if phase == .inactive && oldPhase == .background {
            fetchSeriesWithMetadata()
        }
    }

    func navigateToSeries(_ id: Series.ID) {
        let startTime = Date()

        dependencies.quickActions.reset()

        func scheduleNextRun(time: DispatchTime, id: Series.ID) {
            DispatchQueue.main.asyncAfter(deadline: time) {
                if instance.series.items.first(where: { $0.id == id }) != nil {
                    dependencies.router.seriesPath = .init([Path.series(id)])
                    return
                }

                if Date().timeIntervalSince(startTime) < 5 {
                    scheduleNextRun(time: DispatchTime.now() + 0.1, id: id)
                }
            }
        }

        scheduleNextRun(time: DispatchTime.now(), id: id)
    }
}

#Preview("Offline") {
    dependencies.api.fetchSeries = { _ in
        throw API.Error.notConnectedToInternet
    }

    dependencies.router.selectedTab = .series

    return ContentView()
        .withAppState()
}

#Preview {
    dependencies.router.selectedTab = .series

    return ContentView()
        .withAppState()
}
