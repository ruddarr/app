import SwiftUI

enum SeriesPath: Hashable {
    case search(String = "")
    case preview(Data?)
    case series(Series.ID)
    case edit(Series.ID)
    case releases(Series.ID, Season.ID?, Episode.ID?)
    case season(Series.ID, Season.ID, Episode.ID? = nil)
    case episode(Series.ID, Episode.ID)
}

struct SeriesView: View {
    @AppStorage("seriesSort", store: dependencies.store) var sort: SeriesSort = .init()

    @Environment(AppSettings.self) var settings
    @Environment(SonarrInstance.self) var instance

    @Environment(\.deviceType) private var deviceType

    @State private var scrollView: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var searchPresented = false
    @State private var searchRequest: SearchRequest?

    @State private var error: API.Error?
    @State private var alertPresented = false

    @State private var lastFetch: Date = .distantPast

    @State private var navigationTask: Task<Void, Never>?

    var body: some View {
        // swiftlint:disable:next closure_body_length
        NavigationStack(path: dependencies.$router.seriesPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Sonarr")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            mediaGrid

                            if instance.series.cachedItems.count > 42 {
                                mediaCount
                            }

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
                        await fetchSeriesThrottled()
                    }
                    .refreshable {
                        await Task { await fetchSeriesWithAlert() }.value
                    }
                    .onBecomeActive(perform: becameActive)
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SeriesPath.self) {
                SeriesDestination(path: $0)
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
                toolbarSearchButton

                if settings.sonarrInstances.count > 1 {
                    if deviceType == .phone { toolbarInstancePicker }
                    if deviceType == .pad { bottomBarInstancePicker }
                }
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
            .onChange(of: sort, handleFilterChange)
            .onChange(of: searchQuery, handleQueryChange)
            .onChange(of: instance.series.items, updateDisplayedSeries)
            .task(id: searchRequest) {
                guard let searchRequest, await searchRequest.waitForDebounce() else { return }
                updateDisplayedSeries()
            }
            .sensoryAlert(isPresented: $alertPresented, error: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }.tint(nil)
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if isLoadingSeries {
                    Loading()
                } else if hasNoSearchResults {
                    NoSeriesSearchResults(query: $searchQuery, sort: $sort)
                } else if hasNoMatchingResults {
                    NoMatchingSeries(sort: $sort)
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
    }

    var mediaGrid: some View {
        MediaGrid(
            items: instance.series.cachedItems,
            style: settings.grid
        ) { series in
            NavigationLink(value: SeriesPath.series(series.id)) {
                switch settings.grid {
                case .posters: SeriesGridPoster(series: series)
                case .cards: SeriesGridCard(series: series)
                }
            }
            .buttonStyle(.plain)
            .id(series.id)
        }
        .animation(.snappy, value: instance.series.cachedItems.map(\.id))
        .viewBottomPadding()
        .scenePadding(.horizontal)
        #if os(iOS)
            .padding(.top, searchPresented ? 7 : 0)
        #elseif os(macOS)
            .padding(.vertical)
        #endif
    }

    var mediaCount: some View {
        let items = instance.series.cachedItems
        let episodes = items.reduce(0) { $0 + $1.episodeCount }

        return HStack(spacing: 4) {
            Text("\(items.count) Series")

            if episodes > 0 {
                Bullet()
                Text("\(episodes) Episode")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom)
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
        (instance.series.isWorking || instance.series.isFiltering) &&
        instance.series.cachedItems.isEmpty
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

    func updateSortDirection() {
        sort.isAscending = switch sort.option {
        case .byTitle: true
        default: false
        }
    }

    func updateDisplayedSeries() {
        instance.series.updateCachedItems(sort, searchQuery)
    }

    func fetchSeriesWithMetadata() {
        Task { @MainActor in
            _ = await instance.series.fetch()
            updateDisplayedSeries()

            let lastMetadataFetch = "instanceMetadataFetch:\(instance.id)"
            let cacheInSeconds: Double = instance.isSlow ? 300 : 30

            if Occurrence.since(lastMetadataFetch) > cacheInSeconds {
                if let model = await instance.fetchMetadata() {
                    settings.saveInstanceMetadata(model)
                    Occurrence.occurred(lastMetadataFetch)
                }
            }
        }
    }

    func fetchSeriesThrottled() async {
        guard Date.now.timeIntervalSince(lastFetch) >= 15 else { return }
        _ = await instance.series.fetch()
        updateDisplayedSeries()
        lastFetch = .now
    }

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

    func handleFilterChange() {
        scrollToTop()
        updateDisplayedSeries()
    }

    func handleQueryChange() {
        if let imdb = extractImdbId(searchQuery) {
            searchQuery = "imdb:\(imdb)"
            return
        }

        scrollToTop()
        searchRequest = SearchRequest(query: searchQuery, isDebounced: true)
    }

    func becameActive() {
        guard dependencies.router.seriesPath.isEmpty else { return }
        fetchSeriesWithMetadata()
    }

    func scrollToTop() {
        withAnimation(.smooth) {
            scrollView?.scrollTo(
                instance.series.cachedItems.first?.id
            )
        }
    }

    func maybeSwitchToInstance() {
        guard let idOrName = dependencies.router.switchToSonarrInstance else { return }
        guard let switchTo = settings.instanceBy(idOrName) else { return }

        if switchTo.id != instance.id {
            dependencies.router.switchToSonarrInstance = nil
            settings.sonarrInstanceId = switchTo.id
            changeInstance()
        }
    }

    func navigateToSeries(_ seriesId: Series.ID, _ seasonId: Season.ID?, _ episodeId: Episode.ID?) {
        dependencies.quickActions.clearTimer()
        maybeSwitchToInstance()

        let startTime = Date()

        navigationTask?.cancel()
        navigationTask = Task { @MainActor in
            while Date().timeIntervalSince(startTime) < 10 {
                if Task.isCancelled {
                    return
                }

                if let series = instance.series.items.first(where: { $0.id == seriesId }) {
                    var path: [SeriesPath] = [.series(series.id)]

                    if let seasonId {
                        if let episode = await resolveEpisode(series, seasonId, episodeId) {
                            path.append(SeriesPath.season(seriesId, seasonId))
                            path.append(SeriesPath.episode(seriesId, episode.id))
                        } else {
                            path.append(SeriesPath.season(seriesId, seasonId, episodeId))
                        }
                    }

                    if Task.isCancelled {
                        return
                    }

                    dependencies.router.seriesPath = .init(path)

                    return
                }

                try? await Task.sleep(for: .seconds(0.1))
            }
        }
    }

    func resolveEpisode(_ series: Series, _ seasonId: Season.ID, _ episodeNumber: Episode.ID?) async -> Episode? {
        guard let episodeNumber else { return nil }

        await instance.episodes.maybeFetch(series)

        return instance.episodes.items.first {
            $0.seriesId == series.id && $0.seasonNumber == seasonId && $0.episodeNumber == episodeNumber
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .series

    return ContentView()
        .withAppState()
        .macPreviewFrame()
}

#Preview("Offline") {
    dependencies.api.fetchSeries = { _ in
        throw API.Error.notConnectedToInternet
    }

    dependencies.router.selectedTab = .series

    return ContentView()
        .withAppState()
}
