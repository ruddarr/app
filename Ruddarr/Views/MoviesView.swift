import SwiftUI
import Combine

struct MoviesView: View {
    @AppStorage("movieSort", store: dependencies.store) private var sort: MovieSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: Error?
    @State private var alertPresented = false

    @Environment(\.scenePhase) private var scenePhase

    enum Path: Hashable {
        case search(String = "")
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
                    noRadarrInstance
                } else {
                    ScrollView {
                        movieItemGrid
                            .padding(.top, searchPresented ? 10 : 0)
                            .scenePadding(.horizontal)
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
            .navigationTitle("Movies")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .search(let query):
                    MovieSearchView(searchQuery: query)
                        .environment(instance).environmentObject(settings)
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
            .toolbar {
                toolbarViewOptions

                if settings.radarrInstances.count > 1 {
                    toolbarInstancePicker
                }

                toolbarSearchButton
            }
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .alert("Something Went Wrong", isPresented: $alertPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                if alertErrorMessage == "cancelled" {
                    let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MoviesView") // swiftlint:disable:this redundant_discardable_let
                }

                Text(alertErrorMessage)
            }
            .overlay {
                if case .notConnectedToInternet? = (error as? URLError)?.code {
                    NoInternet()
                } else if displayedMovies.isEmpty && !searchQuery.isEmpty && !instance.isVoid {
                    noSearchResults
                } else if instance.movies.isWorking && instance.movies.items.isEmpty {
                    ProgressView("Loading...").tint(.secondary)
                } else if displayedMovies.isEmpty && !instance.movies.items.isEmpty {
                    noMatchingMovies
                }
            }
        }
        // swiftlint:enable closure_body_length
    }

    var movieItemGrid: some View {
        let gridItemLayout = MovieGridItem.gridItemLayout()

        return LazyVGrid(columns: gridItemLayout, spacing: 15) {
            ForEach(displayedMovies) { movie in
                NavigationLink(value: Path.movie(movie.id)) {
                    MovieGridItem(movie: movie)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var displayedMovies: [Movie] {
        var movies: [Movie] = instance.movies.items

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)

            movies = movies.filter { movie in
                movie.sortTitle.contains(query)
                || (movie.studio?.lowercased() ?? "").contains(query)
            }
        }

        movies = sort.filter.filtered(movies)
        movies = movies.sorted(by: sort.option.isOrderedBefore)

        return sort.isAscending ? movies : movies.reversed()
    }

    var noRadarrInstance: some View {
        ContentUnavailableView(
            "No Radarr Instance",
            systemImage: "externaldrive.badge.xmark",
            description: Text("Connect a Radarr instance under [Settings](#view).")
        ).environment(\.openURL, .init { _ in
            dependencies.router.selectedTab = .settings
            return .handled
        })
    }

    var noSearchResults: some View {
        ContentUnavailableView(
            "No Results for \"\(searchQuery)\"",
            systemImage: "magnifyingglass",
            description: Text("Check the spelling or try [adding the movie](#view).")
        ).environment(\.openURL, .init { _ in
            searchPresented = false
            dependencies.router.moviesPath.append(MoviesView.Path.search(searchQuery))
            searchQuery = ""
            return .handled
        })
    }

    var noMatchingMovies: some View {
        ContentUnavailableView(
            "No Movies Match",
            systemImage: "slash.circle",
            description: Text("No movies match the selected filters.")
        )
    }

    var alertErrorMessage: String {
        let errorText = error?.localizedDescription ?? "An unknown error occurred."

        if let nsError = error as? NSError,
           let suggestion = nsError.localizedRecoverySuggestion {
            return "\(errorText)\n\n\(suggestion)"
        }

        return errorText
    }

    func fetchMoviesWithMetadata() {
        Task { @MainActor in
            _ = await instance.movies.fetch()

            if let model = await instance.fetchMetadata() {
                settings.saveInstance(model)
            }
        }
    }

    @MainActor
    func fetchMoviesWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.movies.fetch()

        if instance.movies.error is CancellationError {
            return
        }

        if let urlError = instance.movies.error as? URLError, urlError.code == .cancelled {
            return
        }

        if instance.movies.error != nil {
            error = instance.movies.error

            if ignoreOffline && (instance.movies.error as? URLError)?.code == .notConnectedToInternet {
                return
            }

            alertPresented = instance.movies.error != nil
        }
    }
}

extension MoviesView {
    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if !instance.isVoid {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Path.search()) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarViewOptions: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack {
                toolbarFilterButton
                toolbarSortingButton
            }
        }
    }

    var toolbarFilterButton: some View {
        Menu("Filters", systemImage: "line.3.horizontal.decrease") {
            Picker(selection: $sort.filter, label: Text("Filter options")) {
                ForEach(MovieSort.Filter.allCases) { filter in
                    filter.label
                }
            }
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Picker(selection: $sort.option, label: Text("Sorting options")) {
                ForEach(MovieSort.Option.allCases) { option in
                    option.label
                }
            }.onChange(of: sort.option) {
                switch sort.option {
                case .byTitle: sort.isAscending = true
                case .byYear: sort.isAscending = false
                case .byAdded: sort.isAscending = false
                }
            }

            Section {
                Picker(selection: $sort.isAscending, label: Text("Sorting direction")) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }

    @ToolbarContentBuilder
    var toolbarInstancePicker: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Menu {
                Picker(selection: $settings.radarrInstanceId, label: Text("Instances")) {
                    ForEach(settings.radarrInstances) { instance in
                        Text(instance.label).tag(Optional.some(instance.id))
                    }
                }
                .onChange(of: settings.radarrInstanceId, changeInstance)
            } label: {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(settings.radarrInstance?.label ?? "Instance")
                        .fontWeight(.semibold)
                        .tint(.primary)

                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundStyle(.secondary, .tertiarySystemBackground)
                        .font(.system(size: 13))
                }.tint(.primary)
            }
        }
    }

    func changeInstance() {
        Task { @MainActor in
            instance.switchTo(
                settings.instanceById(settings.radarrInstanceId!)!
            )

            await fetchMoviesWithAlert()

            if let model = await instance.fetchMetadata() {
                settings.saveInstance(model)
            }
        }
    }
}

#Preview("Offline") {
    dependencies.api.fetchMovies = { _ in
        throw URLError(.notConnectedToInternet)
    }

    return ContentView()
        .withAppState()
}

#Preview("Failure") {
    dependencies.api.fetchMovies = { _ in
        throw URLError(.badServerResponse)
    }

    return ContentView()
        .withAppState()
}

#Preview("Timeout") {
    dependencies.api.fetchMovies = { _ in
        throw URLError(.timedOut)
    }

    return ContentView()
        .withAppState()
}

#Preview {
    ContentView()
        .withAppState()
}
