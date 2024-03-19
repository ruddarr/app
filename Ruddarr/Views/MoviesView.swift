import SwiftUI
import Combine

struct MoviesView: View {
    @AppStorage("movieSort", store: dependencies.store) var sort: MovieSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) var instance

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: API.Error?
    @State private var alertPresented = false

    @Environment(\.scenePhase) private var scenePhase

    enum Path: Hashable {
        case search(String = "")
        case preview(Data?)
        case movie(Movie.ID)
        case edit(Movie.ID)
        case releases(Movie.ID)
    }

    var body: some View {
        // swiftlint:disable closure_body_length
        NavigationStack(
            path: dependencies.$router.moviesPath
        ) {
            Group {
                if instance.isVoid {
                    NoRadarrInstance()
                } else {
                    ScrollView {
                        movieItemGrid
                            .padding(.top, searchPresented ? 10 : 0)
                            .viewPadding(.horizontal)
                    }
                    .task(priority: .low) {
                        guard !instance.isVoid else { return }
                        await fetchMoviesWithAlert(ignoreOffline: true)
                    }
                    .refreshable {
                        await fetchMoviesWithAlert()
                    }
                    .onChange(of: scenePhase) { previous, phase in
                        if phase == .inactive && previous == .background {
                            fetchMoviesWithMetadata()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .search(let query):
                    MovieSearchView(searchQuery: query)
                        .environment(instance).environmentObject(settings)
                case .preview(let data):
                    if let payload = data,
                       let movie = try? JSONDecoder().decode(Movie.self, from: payload)
                    {
                        MoviePreviewView(movie: movie)
                            .environment(instance).environmentObject(settings)
                    }
                case .movie(let movieId):
                    if let movie = instance.movies.byId(movieId).unwrapped {
                        MovieView(movie: movie)
                            .environment(instance).environmentObject(settings)
                    }
                case .edit(let movieId):
                    if let movie = instance.movies.byId(movieId).unwrapped {
                        MovieEditView(movie: movie)
                            .environment(instance).environmentObject(settings)
                    }
                case .releases(let movieId):
                    if let movie = instance.movies.byId(movieId).unwrapped {
                        MovieReleasesView(movie: movie)
                            .environment(instance).environmentObject(settings)
                    }
                }
            }
            .onAppear {
                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if instance.isVoid, let first = settings.radarrInstances.first {
                    instance.switchTo(first)
                    settings.radarrInstanceId = first.id
                }
            }
            .onReceive(dependencies.quickActions.moviePublisher, perform: navigateToMovie)
            .toolbar {
                toolbarViewOptions

                if settings.radarrInstances.count > 1 {
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
                updateDisplayedMovies()
            }
            .alert(isPresented: $alertPresented, error: error) { _ in } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if hasNoSearchResults {
                    MovieNoSearchResults(query: $searchQuery)
                } else if isLoadingMovies {
                    ProgressView("Loading...").tint(.secondary)
                } else if hasNoMatchingResults {
                    NoMatchingMovies()
                }
            }
        }
        // swiftlint:enable closure_body_length
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
        instance.movies.cachedItems.isEmpty && !instance.movies.items.isEmpty
    }

    var isLoadingMovies: Bool {
        instance.movies.isWorking && instance.movies.cachedItems.isEmpty
    }

    var movieItemGrid: some View {
        let gridItemLayout = MovieGridItem.gridItemLayout()
        let gridItemSpacing = MovieGridItem.gridItemSpacing()

        return LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
            ForEach(displayedMovies) { movie in
                NavigationLink(value: Path.movie(movie.id)) {
                    MovieGridItem(movie: movie)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var displayedMovies: [Movie] {
        instance.movies.cachedItems
    }

    func updateDisplayedMovies() {
        instance.movies.sortAndFilterItems(sort, searchQuery)
    }

    func fetchMoviesWithMetadata() {
        Task { @MainActor in
            _ = await instance.movies.fetch()
            updateDisplayedMovies()

            let lastMetadataFetch = "instanceMetadataFetch:\(instance.id)"

            if Occurrence.since(lastMetadataFetch) > 30 {
                if let model = await instance.fetchMetadata() {
                    settings.saveInstance(model)
                    Occurrence.occurred(lastMetadataFetch)
                }
            }
        }
    }

    @MainActor
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

    func navigateToMovie(_ id: Movie.ID) {
        let startTime = Date()

        func scheduleNextRun(time: DispatchTime, id: Movie.ID) {
            DispatchQueue.main.asyncAfter(deadline: time) {
                if instance.movies.items.first(where: { $0.id == id }) != nil {
                    dependencies.router.moviesPath = .init([Path.movie(id)])
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
