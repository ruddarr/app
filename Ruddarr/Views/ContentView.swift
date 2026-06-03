import SwiftUI

#if os(iOS)
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        TabView(selection: selectedTab) {
            Tab(movies.label, image: movies.icon, value: movies) {
                MoviesView()
            }

            Tab(series.label, image: series.icon, value: series) {
                SeriesView()
            }

            Tab(calendar.label, systemImage: calendar.icon, value: calendar) {
                CalendarView()
            }

            Tab(activity.label, systemImage: activity.icon, value: activity) {
                ActivityView()
            }
            .badge(Queue.shared.itemsWithIssues)

            Tab(TabItem.settings.label, systemImage: TabItem.settings.icon, value: TabItem.settings) {
                SettingsView()
            }
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.never)
        .tabViewSidebarHeader {
            Text(verbatim: Ruddarr.name)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if !isRunningIn(.preview) {
                dependencies.router.selectedTab = settings.tab
            }
            UITabBarItem.appearance().badgeColor = UIColor(settings.theme.tint)
        }
        .onBecomeActive(perform: handleScenePhaseChange)
        .sheet(item: dependencies.$router.mediaSheetRoute, onDismiss: {
            dependencies.router.mediaSheetPath = .init()
        }, content: { route in
            MediaSheet(route: route)
                .environmentObject(settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.sheetBackground)
        })
        .displayToasts()
        .whatsNewSheet()
        .reportBugSheet()
    }

    var movies: TabItem { .movies }
    var series: TabItem { .series }
    var calendar: TabItem { .calendar }
    var activity: TabItem { .activity }

    var selectedTab: Binding<TabItem> {
        Binding<TabItem>(
            get: {
                dependencies.router.selectedTab
            },
            set: {
                let from = dependencies.router.selectedTab
                dependencies.router.selectedTab = $0
                handleTabChange(from, $0)
            }
        )
    }

    func handleScenePhaseChange() async {
        Telemetry.maybePing(with: settings)
        Notifications.maybeUpdateWebhooks(settings)
    }

    func handleTabChange(_ from: TabItem, _ to: TabItem) {
        guard from == to else { return }

        switch to {
        case .calendar: NotificationCenter.default.post(name: .scrollToToday)
        default: break
        }
    }
}

private struct MediaSheet: View {
    let route: MediaSheetRoute

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        switch route.kind {
        case .movie:
            MovieMediaSheet(route: route, instanceModel: radarrInstance)
                .environmentObject(settings)
        case .series:
            SeriesMediaSheet(route: route, instanceModel: sonarrInstance)
                .environmentObject(settings)
        }
    }

    var radarrInstance: Instance {
        if let id = route.instanceId, let instance = settings.instanceById(id) {
            return instance
        }
        return settings.radarrInstance ?? .radarrVoid
    }

    var sonarrInstance: Instance {
        if let id = route.instanceId, let instance = settings.instanceById(id) {
            return instance
        }
        return settings.sonarrInstance ?? .sonarrVoid
    }
}

private struct MovieMediaSheet: View {
    let route: MediaSheetRoute
    @State private var instance: RadarrInstance
    @EnvironmentObject private var settings: AppSettings

    init(route: MediaSheetRoute, instanceModel: Instance) {
        self.route = route

        let instance = RadarrInstance(instanceModel)

        if let movie = route.movie {
            instance.movies.items = [movie]
            instance.movies.cachedItems = [movie]
            instance.movies.itemsCount = 1
        }

        self._instance = State(wrappedValue: instance)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.mediaSheetPath) {
            if let movieId = route.movieId {
                destination(for: .movie(movieId))
                    .navigationDestination(for: MoviesPath.self, destination: destination)
            } else {
                unavailable
            }
        }
        .environment(instance)
        .task {
            await prepareMovie()
        }
    }

    @ViewBuilder
    func destination(for path: MoviesPath) -> some View {
        switch path {
        case .search(let query):
            MovieSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            moviePreview(data)
        case .movie(let id):
            movieContent(id) { movie in
                MovieView(movie: movie)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .edit(let id):
            movieContent(id) { movie in
                MovieEditView(movie: movie)
                    .environment(instance)
            }
        case .releases(let id):
            movieContent(id) { movie in
                MovieReleasesView(movie: movie)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .metadata(let id):
            movieContent(id) { movie in
                MovieMetadataView(movie: movie)
                    .environment(instance)
            }
        }
    }

    @ViewBuilder
    func moviePreview(_ data: Data?) -> some View {
        if let data, let movie = try? JSONDecoder().decode(Movie.self, from: data) {
            MoviePreviewView(movie: movie)
                .environment(instance)
                .environmentObject(settings)
        } else {
            unavailable
        }
    }

    @ViewBuilder
    func movieContent<Content: View>(
        _ id: Movie.ID,
        @ViewBuilder content: (Binding<Movie>) -> Content
    ) -> some View {
        if instance.movies.byId(id) != nil {
            content(instance.movies.byId(id))
        } else {
            loading
        }
    }

    var loading: some View {
        Loading()
            .task {
                await prepareMovie()
            }
    }

    var unavailable: some View {
        ContentUnavailableView("Unable to Load Item", systemImage: "exclamationmark.triangle")
    }

    func prepareMovie() async {
        guard let movieId = route.movieId else { return }
        guard instance.movies.byId(movieId) == nil else { return }

        _ = await instance.movies.fetch()
    }
}

private struct SeriesMediaSheet: View {
    let route: MediaSheetRoute
    @State private var instance: SonarrInstance
    @EnvironmentObject private var settings: AppSettings

    init(route: MediaSheetRoute, instanceModel: Instance) {
        self.route = route

        let instance = SonarrInstance(instanceModel)

        if var series = route.series ?? route.episode?.series {
            series.instanceId = route.instanceId
            instance.series.items = [series]
            instance.series.cachedItems = [series]
            instance.series.itemsCount = 1
        }

        if var episode = route.episode {
            episode.instanceId = route.instanceId
            instance.episodes.items = [episode]
        }

        self._instance = State(wrappedValue: instance)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.mediaSheetPath) {
            if let seriesId = route.seriesId {
                destination(for: .series(seriesId))
                    .navigationDestination(for: SeriesPath.self, destination: destination)
            } else {
                unavailable
            }
        }
        .environment(instance)
        .task {
            await prepareSeries()
        }
    }

    @ViewBuilder
    func destination(for path: SeriesPath) -> some View {
        switch path {
        case .search(let query):
            SeriesSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            seriesPreview(data)
        case .series(let id):
            seriesContent(id) { series in
                SeriesDetailView(series: series)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .edit(let id):
            seriesContent(id) { series in
                SeriesEditView(series: series)
                    .environment(instance)
            }
        case .releases(let id, let season, let episode):
            seriesContent(id) { series in
                SeriesReleasesView(
                    series: series,
                    seasonId: season,
                    episodeId: episode
                )
                .environment(instance)
                .environmentObject(settings)
            }
        case .season(let id, let season, let episode):
            seriesContent(id) { series in
                SeasonView(series: series, seasonId: season, jumpToEpisode: episode)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .episode(let id, let episode):
            seriesContent(id) { series in
                EpisodeView(series: series, episodeId: episode)
                    .environment(instance)
                    .environmentObject(settings)
            }
        }
    }

    @ViewBuilder
    func seriesPreview(_ data: Data?) -> some View {
        if let data, let series = try? JSONDecoder().decode(Series.self, from: data) {
            SeriesPreviewView(series: series)
                .environment(instance)
                .environmentObject(settings)
        } else {
            unavailable
        }
    }

    @ViewBuilder
    func seriesContent<Content: View>(
        _ id: Series.ID,
        @ViewBuilder content: (Binding<Series>) -> Content
    ) -> some View {
        if instance.series.byId(id) != nil {
            content(instance.series.byId(id))
        } else {
            loading
        }
    }

    var loading: some View {
        Loading()
            .task {
                await prepareSeries()
            }
    }

    var unavailable: some View {
        ContentUnavailableView("Unable to Load Item", systemImage: "exclamationmark.triangle")
    }

    func prepareSeries() async {
        guard let seriesId = route.seriesId else { return }

        if instance.series.byId(seriesId) == nil {
            _ = await instance.series.fetch()
        }

        guard let series = instance.series.byId(seriesId) else { return }

        async let maybeFetchEpisodes: () = instance.episodes.maybeFetch(series)
        async let maybeFetchFiles: () = instance.files.maybeFetch(series)
        (_, _) = await (maybeFetchEpisodes, maybeFetchFiles)
    }
}
#endif

#Preview {
    ContentView()
        .withAppState()
}
