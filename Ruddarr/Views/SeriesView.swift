import SwiftUI
import Combine

enum SeriesPath: Hashable {
    case search(String = "")
    case preview(Data?)
    case series(Series.ID)
    case edit(Series.ID)
    case releases(Series.ID, Season.ID?, Episode.ID?)
    case season(Series.ID, Season.ID)
    case episode(Series.ID, Episode.ID)
}

struct SeriesView: View {
    @AppStorage("seriesSort", store: dependencies.store) var sort: SeriesSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @State private var scrollView: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: API.Error?
    @State private var alertPresented = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        // swiftlint:disable closure_body_length
        NavigationStack(path: dependencies.$router.seriesPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Sonarr")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            seriesItemGrid
                                .viewBottomPadding()
                                .viewPadding(.horizontal)
                                #if os(iOS)
                                    .padding(.top, searchPresented ? 7 : 0)
                                #endif

                            if presentSearchSuggestion {
                                SeriesSearchSuggestion(query: $searchQuery, sort: $sort)
                            }
                        }
                        .onAppear {
                            scrollView = proxy
                        }
                    }
                    .task {
                        guard !instance.isVoid else { return }
                        await fetchSeriesWithAlert(ignoreOffline: true)
                    }
                    .refreshable {
                        await Task { await fetchSeriesWithAlert() }.value
                    }
                    .onChange(of: scenePhase, handleScenePhaseChange)
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SeriesPath.self) {
                switch $0 {
                case .search(let query):
                    SeriesSearchView(searchQuery: query)
                        .environment(instance)
                        .environmentObject(settings)
                case .preview(let data):
                    if let series = try? JSONDecoder().decode(Series.self, from: data!) {
                        SeriesPreviewView(series: series)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .series(let id):
                    if let series = instance.series.byId(id).unwrapped {
                        SeriesDetailView(series: series)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .edit(let id):
                    if let series = instance.series.byId(id).unwrapped {
                        SeriesEditView(series: series)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .releases(let id, let season, let episode):
                    if let series = instance.series.byId(id).unwrapped {
                        SeriesReleasesView(series: series, seasonId: season, episodeId: episode)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .season(let id, let season):
                    if let series = instance.series.byId(id).unwrapped {
                        SeasonView(series: series, seasonId: season)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                case .episode(let id, let episode):
                    if let series = instance.series.byId(id).unwrapped {
                        EpisodeView(series: series, episodeId: episode)
                            .environment(instance)
                            .environmentObject(settings)
                    }
                }
            }
            .onAppear {
                // if a deeplink set an instance, try to switch to it
                maybeSwitchToInstance()

                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if instance.isVoid, let first = settings.sonarrInstances.first {
                    settings.sonarrInstanceId = first.id
                    changeInstance()
                }
            }
            .onReceive(dependencies.quickActions.seriesPublisher, perform: navigateToSeries)
            .toolbar {
                toolbarViewOptions

                if settings.sonarrInstances.count > 1 && deviceType == .phone {
                    toolbarInstancePicker
                }

                toolbarSearchButton
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .drawerOrToolbar
            )
            .autocorrectionDisabled(true)
            .onChange(of: settings.sonarrInstanceId, changeInstance)
            .onChange(of: sort.option, updateSortDirection)
            .onChange(of: [sort, searchQuery] as [AnyHashable]) {
                scrollToTop()
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
                    NoSeriesSearchResults(query: $searchQuery, sort: $sort)
                } else if isLoadingSeries {
                    Loading()
                } else if hasNoMatchingResults {
                    NoMatchingSeries(sort: $sort)
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

    var presentSearchSuggestion: Bool {
        searchPresented && !instance.series.cachedItems.isEmpty
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
                NavigationLink(value: SeriesPath.series(series.id)) {
                    SeriesGridItem(series: series)
                }
                .buttonStyle(.plain)
                .id(series.id)
            }
        }
        #if os(macOS)
            .padding(.vertical)
        #endif
    }

    func updateSortDirection() {
        switch sort.option {
        case .byTitle:
            sort.isAscending = true
        default:
            sort.isAscending = false
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
            let cacheInSeconds: Double = instance.isSlow ? 300 : 30

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

    func scrollToTop() {
        scrollView?.scrollTo(
            instance.series.cachedItems.first?.id
        )
    }

    func maybeSwitchToInstance() {
        guard let idOrName = dependencies.router.switchToRadarrInstance else { return }
        guard let switchTo = settings.instanceBy(idOrName) else { return }

        if switchTo.id != instance.id {
            dependencies.router.switchToRadarrInstance = nil
            settings.radarrInstanceId = switchTo.id
            changeInstance()
        }
    }

    func navigateToSeries(_ id: Series.ID, season: Season.ID?) {
        dependencies.quickActions.clearTimer()
        maybeSwitchToInstance()

        let startTime = Date()

        func scheduleNextRun(time: DispatchTime, id: Series.ID) {
            DispatchQueue.main.asyncAfter(deadline: time) {
                if let series = instance.series.items.first(where: { $0.id == id }) {
                    dependencies.router.seriesPath = .init([SeriesPath.series(series.id)])

                    if let seasonId = season {
                        dependencies.router.seriesPath.append(SeriesPath.season(id, seasonId))
                    }

                    return
                }

                if Date().timeIntervalSince(startTime) < 10 {
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
