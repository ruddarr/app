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

    @State private var noInstance = true

    @Environment(\.scenePhase) private var scenePhase

    enum Path: Hashable {
        case search(String = "")
        case movie(Movie.ID)
        case edit(Movie.ID)
    }

    var body: some View {
        let gridItemLayout = [
            GridItem(.adaptive(minimum: 300), spacing: 15)
        ]

        NavigationStack(path: dependencies.$router.moviesPath) {
            Group {
                if noInstance {
                    noRadarrInstance
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 15) {
                            ForEach(displayedMovies) { movie in
                                NavigationLink(value: Path.movie(movie.id)) {
                                    MovieRow(movie: movie)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, searchPresented ? 10 : 0)
                        .scenePadding(.horizontal)
                    }
                    .task(priority: .low) {
                        await fetchMoviesWithAlert(ignoreOffline: true)
                    }
                    .refreshable {
                        await fetchMoviesWithAlert()
                    }
                    .onChange(of: scenePhase) { newPhase, oldPhase in
                        guard newPhase == .background && oldPhase == .inactive else { return }

                        Task {
                            _ = await instance.movies.fetch()

                            if let model = try await instance.fetchMetadata() {
                                settings.saveInstance(model)
                            }
                       }
                    }
                }
            }
            .navigationTitle("Movies")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .search(let query):
                    MovieSearchView(searchQuery: query)
                case .movie(let movieId):
                    if let movie = instance.movies.byId(movieId) {
                        MovieView(movie: movie)
                    } else {
                        var _ = assertionFailure("Invalid Movie.ID for MovieView") }
                case .edit(let movieId):
                    if let movie = instance.movies.byId(movieId) {
                        MovieEditView(movie: movie)
                    } else {
                        var _ = assertionFailure("Invalid Movie.ID for MovieEditView")
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

                noInstance = instance.isVoid
            }
            .toolbar {
                toolbarActionButtons
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
                Text(error?.localizedDescription ?? "An unknown error occurred.")
            }
            .overlay {
                if case .notConnectedToInternet? = (error as? URLError)?.code {
                    NoInternet()
                } else if displayedMovies.isEmpty && !searchQuery.isEmpty && !instance.isVoid {
                    noSearchResults
                } else if instance.movies.isWorking && instance.movies.items.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    var noRadarrInstance: some View {
        ContentUnavailableView(
            "No Radarr Instance",
            systemImage: "externaldrive.badge.xmark",
            description: Text("Connect a Radarr instance under [Settings](#view).")
        )
        .environment(\.openURL, .init { _ in
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
    var toolbarActionButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if settings.radarrInstances.count > 1 {
                toolbarInstancesButton
            }

            toolbarSortingButton
        }
    }

    var toolbarSortingButton: some View {
        Menu("Sorting", systemImage: "arrow.up.arrow.down") {
            Picker(selection: $sort.option, label: Text("Sorting options")) {
                ForEach(MovieSort.Option.allCases) { sortOption in
                    Text(sortOption.title).tag(sortOption)
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
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        }
    }

    var toolbarInstancesButton: some View {
        Menu("Instances", systemImage: "xserve.raid") {
            Picker(selection: $settings.radarrInstanceId, label: Text("Instance")) {
                ForEach(settings.radarrInstances) { instance in
                    Text(instance.label).tag(Optional.some(instance.id))
                }
            }
            .onChange(of: settings.radarrInstanceId) {
                Task {
                    instance.switchTo(
                        settings.instanceById(settings.radarrInstanceId!)!
                    )

                    await fetchMoviesWithAlert()

                    if let model = try await instance.fetchMetadata() {
                        settings.saveInstance(model)
                    }
                }
            }
        }
    }

    var displayedMovies: [Movie] {
        let unsortedMovies: [Movie]

        if searchQuery.isEmpty {
            unsortedMovies = instance.movies.items
        } else {
            unsortedMovies = instance.movies.items.filter { movie in
                movie.title.localizedCaseInsensitiveContains(
                    searchQuery.trimmingCharacters(in: .whitespaces)
                )
            }
        }

        let sortedMovies = unsortedMovies.sorted(by: sort.option.isOrderedBefore)

        return sort.isAscending ? sortedMovies : sortedMovies.reversed()
    }

    func fetchMoviesWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.movies.fetch()

        if instance.movies.error != nil {
            error = instance.movies.error

            if ignoreOffline && (instance.movies.error as? URLError)?.code == .notConnectedToInternet {
                return
            }

            alertPresented = instance.movies.error != nil
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

#Preview {
    ContentView()
        .withAppState()
}
