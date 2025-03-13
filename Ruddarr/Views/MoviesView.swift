import SwiftUI
import Combine

enum MoviesPath: Hashable {
    case search(String = "")
    case preview(Data?)
    case movie(Movie.ID)
    case edit(Movie.ID)
    case releases(Movie.ID)
    case metadata(Movie.ID)
}

struct MoviesView: View {
    @AppStorage("movieSort", store: dependencies.store) var sort: MovieSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) var instance

    @State private var scrollView: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: API.Error?
    @State private var alertPresented = false

    @State private var lastFetch: Date = .distantPast

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        // swiftlint:disable closure_body_length
        NavigationStack(path: dependencies.$router.moviesPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Radarr")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            movieItemGrid
                                .viewBottomPadding()
                                .viewPadding(.horizontal)
                                #if os(iOS)
                                    .padding(.top, searchPresented ? 7 : 0)
                                #endif

                            if presentSearchSuggestion {
                                MovieSearchSuggestion(query: $searchQuery, sort: $sort)
                            }
                        }
                        .onAppear {
                            scrollView = proxy
                        }
                    }
                    .task {
                        guard !instance.isVoid else { return }
                        await fetchMoviesWithAlertThrottled(ignoreOffline: true)
                    }
                    .refreshable {
                        await Task { await fetchMoviesWithAlert() }.value
                    }
                    .onChange(of: scenePhase, handleScenePhaseChange)
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MoviesPath.self) {
                destination(for: $0)
            }
            .onAppear {
                // if a deeplink set an instance, try to switch to it
                maybeSwitchToInstance()

                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if instance.isVoid, let first = settings.radarrInstances.first {
                    settings.radarrInstanceId = first.id
                    changeInstance()
                }
                
                // Listen for tab activation
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("ActivateMoviesSearch"),
                    object: nil,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        searchPresented = true
                    }
                }
            }
            .onReceive(dependencies.quickActions.moviePublisher, perform: navigateToMovie)
            .toolbar {
                toolbarViewOptions

                if settings.radarrInstances.count > 1 && deviceType == .phone {
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
            .onChange(of: settings.radarrInstanceId, changeInstance)
            .onChange(of: sort.option, updateSortDirection)
            .onChange(of: [sort, searchQuery] as [AnyHashable]) {
                if let imdb = extractImdbId(searchQuery) {
                    searchQuery = "imdb:\(imdb)"
                    return
                }

                scrollToTop()
                updateDisplayedMovies()
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
                    NoMovieSearchResults(query: $searchQuery, sort: $sort)
                } else if isLoadingMovies {
                    Loading()
                } else if hasNoMatchingResults {
                    NoMatchingMovies(sort: $sort)
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
        // swiftlint:enable closure_body_length
    }

    @ViewBuilder
    func destination(for path: MoviesPath) -> some View {
        switch path {
        case .search(let query):
            MovieSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            if let data, let movie = try? JSONDecoder().decode(Movie.self, from: data) {
                MoviePreviewView(movie: movie)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .movie(let id):
            MovieView(movie: instance.movies.byId(id))
                .environment(instance)
                .environmentObject(settings)
        case .edit(let id):
            MovieEditView(movie: instance.movies.byId(id))
                .environment(instance)
        case .releases(let id):
            MovieReleasesView(movie: instance.movies.byId(id))
                .environment(instance)
                .environmentObject(settings)
        case .metadata(let id):
            MovieMetadataView(movie: instance.movies.byId(id))
                .environment(instance)
        }
    }

    var notConnectedToInternet: Bool {
        if !instance.movies.cachedItems.isEmpty { return false }
        if case .notConnectedToInternet = error { return true }
        return false
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && !instance.isVoid && instance.movies.cachedItems.isEmpty
    }

    var hasNoMatchingResults: Bool {
        instance.movies.cachedItems.isEmpty && instance.movies.itemsCount > 0
    }

    var presentSearchSuggestion: Bool {
        searchPresented && !instance.movies.cachedItems.isEmpty
    }

    var isLoadingMovies: Bool {
        instance.movies.isWorking && instance.movies.cachedItems.isEmpty
    }

    var initialLoadingFailed: Bool {
        guard instance.movies.itemsCount == 0 else { return false }
        return instance.movies.error != nil
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("Connection Failure", systemImage: "exclamationmark.triangle")
        } description: {
            Text(instance.movies.error?.recoverySuggestionFallback ?? "")
        } actions: {
            Button("Retry") {
                Task { await fetchMoviesWithAlert(ignoreOffline: true) }
            }
        }
    }

    @ViewBuilder
    var movieItemGrid: some View {
        let gridItemLayout = MovieGridItem.gridItemLayout()
        let gridItemSpacing = MovieGridItem.gridItemSpacing()

        LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
            ForEach(instance.movies.cachedItems) { movie in
                NavigationLink(value: MoviesPath.movie(movie.id)) {
                    MovieGridItem(movie: movie)
                }
                .buttonStyle(.plain)
                .id(movie.id)
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

    func updateDisplayedMovies() {
        instance.movies.updateCachedItems(sort, searchQuery)
    }

    func fetchMoviesWithMetadata() {
        Task { @MainActor in
            _ = await instance.movies.fetch()
            updateDisplayedMovies()

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

    func fetchMoviesWithAlertThrottled(ignoreOffline: Bool = false) async {
        guard Date.now.timeIntervalSince(lastFetch) >= 15 else { return }
        await fetchMoviesWithAlert(ignoreOffline: ignoreOffline)
        lastFetch = .now
    }

    func fetchMoviesWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.movies.fetch()
        updateDisplayedMovies()

        if let apiError = instance.movies.error {
            error = apiError

            if case .notConnectedToInternet = apiError, ignoreOffline {
                return
            }

            alertPresented = true
        }
    }

    func handleScenePhaseChange(_ from: ScenePhase, _ to: ScenePhase) {
        guard dependencies.router.moviesPath.isEmpty else {
            return
        }

        if from == .background, to == .inactive {
            fetchMoviesWithMetadata()
        }
    }

    func scrollToTop() {
        scrollView?.scrollTo(
            instance.movies.cachedItems.first?.id
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

    func navigateToMovie(_ id: Movie.ID) {
        dependencies.quickActions.clearTimer()
        maybeSwitchToInstance()

        let startTime = Date()

        func scheduleNextRun(time: DispatchTime, id: Movie.ID) {
            DispatchQueue.main.asyncAfter(deadline: time) {
                if let movie = instance.movies.items.first(where: { $0.id == id }) {
                    dependencies.router.moviesPath = .init([MoviesPath.movie(movie.id)])
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
    dependencies.api.fetchMovies = { _ in
        throw API.Error.notConnectedToInternet
    }

    return ContentView()
        .withAppState()
}

#Preview("Failure") {
    dependencies.api.fetchMovies = { _ in
        throw API.Error.urlError(
            URLError(.badServerResponse)
        )
    }

    return ContentView()
        .withAppState()
}

#Preview("Timeout") {
    dependencies.api.fetchMovies = { _ in
        throw API.Error.timeoutOnPrivateIp(
            URLError(.timedOut)
        )
    }

    return ContentView()
        .withAppState()
}

#Preview {
    ContentView()
        .withAppState()
}
