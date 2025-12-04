import SwiftUI

struct MovieDiscoveryView: View {
    @State private var movies: [Movie] = []
    @State private var isLoading = true
    @State private var error: (any Error)?
    @State private var page = 1
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var filter: DiscoveryFilter = .all
    @State private var category: TMDB.Category = .trending // NEW STATE

    // Cache library for O(1) lookup
    @State private var libraryLookup: [Int: Movie] = [:]

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    enum DiscoveryFilter: String, CaseIterable, Identifiable {
        var id: Self { self }
        case all = "All"
        case inLibrary = "In Library"
        case notInLibrary = "Missing"
    }

    var body: some View {
        ScrollView {
            if settings.tmdbApiKey.isEmpty {
                apiKeysMissing
            } else if isLoading {
                Loading()
                    .padding(.top, 100)
            } else if let error = error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .padding(.top, 50)
            } else {
                grid
                if hasMore {
                    loadMoreButton
                }
            }
        }
        .navigationTitle(category.label) // Updates title dynamically
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarFilterButton
            toolbarCategoryButton // Add the new button
        }
        .task {
            refreshLibraryIndex()
            if movies.isEmpty {
                await fetchInitial()
            }
        }
        .onChange(of: instance.movies.items) {
            refreshLibraryIndex()
            movies = processMovies(movies)
        }
        .onChange(of: category) { // Reset and reload when category changes
            Task { await fetchInitial() }
        }
    }

    var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedMovies) { movie in
                NavigationLink(value: destination(for: movie)) {
                    MovieGridPoster(movie: movie)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Trigger pagination when reaching near the end
                    if let index = displayedMovies.firstIndex(where: { $0.id == movie.id }),
                       index >= displayedMovies.count - 6 {
                        Task {
                            await fetchNextPage()
                        }
                    }
                }
            }
        }
        .viewPadding(.horizontal)
        .padding(.top, 12)
    }
    var displayedMovies: [Movie] {
        switch filter {
        case .all: return movies
        case .inLibrary: return movies.filter { $0.exists }
        case .notInLibrary: return movies.filter { !$0.exists }
        }
    }
    @ToolbarContentBuilder
    var toolbarFilterButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(DiscoveryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                if filter != .all {
                    Image("filters.badge")
                        .offset(y: 3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(settings.theme.tint, .primary)
                } else {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
    }
    @ToolbarContentBuilder
    var toolbarCategoryButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Category", selection: $category) {
                    Text("Trending").tag(TMDB.Category.trending)
                    Text("Popular").tag(TMDB.Category.popular)
                    Text("Top Rated").tag(TMDB.Category.topRated)
                    Text("Upcoming").tag(TMDB.Category.upcoming)
                }
                .pickerStyle(.inline)
                Section("Genres") {
                    Picker("Genre", selection: $category) {
                        ForEach(TMDB.sortedMovieGenres, id: \.id) { genre in
                            Text(genre.name).tag(TMDB.Category.genre(genre.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            } label: {
                Image(systemName: "list.bullet")
            }
        }
    }

    var loadMoreButton: some View {
        ProgressView()
            .tint(.secondary)
            .padding(.vertical, 24)
            .viewBottomPadding()
    }
    var apiKeysMissing: some View {
        ContentUnavailableView(
            "API Key Required",
            systemImage: "key",
            description: Text("Please enter your TMDB API Key in Settings > Discovery.")
        )
        .padding(.top, 50)
    }

    func refreshLibraryIndex() {
        libraryLookup = Dictionary(uniqueKeysWithValues: instance.movies.items.map { ($0.tmdbId, $0) })
    }

    func fetchInitial() async {
        guard !settings.tmdbApiKey.isEmpty else {
            isLoading = false
            return
        }
        // Reset state
        movies = []
        page = 1
        hasMore = true
        isLoading = true
        error = nil

        do {
            let result = try await TMDB.fetchMovies(category, apiKey: settings.tmdbApiKey, page: page)
            self.movies = processMovies(result.movies)
            self.hasMore = result.hasMore
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func fetchNextPage() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = page + 1
            let result = try await TMDB.fetchMovies(category, apiKey: settings.tmdbApiKey, page: nextPage)
            try Task.checkCancellation()
            page = nextPage
            self.hasMore = result.hasMore
            let existingIds = Set(movies.map { $0.tmdbId })
            let uniqueMovies = result.movies.filter { !existingIds.contains($0.tmdbId) }
            if !uniqueMovies.isEmpty {
                self.movies.append(contentsOf: processMovies(uniqueMovies))
            }
            if !uniqueMovies.isEmpty && displayedMovies.count < 10 && hasMore {
                try? await Task.sleep(for: .milliseconds(100))
                await fetchNextPage()
            }
        } catch {
            if !(error is CancellationError) {
                dependencies.toast.show(.error(error.localizedDescription))
            }
        }
    }

    func processMovies(_ input: [Movie]) -> [Movie] {
        input.map { tmdbMovie in
            if let local = libraryLookup[tmdbMovie.tmdbId] {
                return local
            }
            return tmdbMovie
        }
    }

    func destination(for movie: Movie) -> MoviesPath {
        if movie.exists {
            return .movie(movie.id)
        }

        do {
            let data = try JSONEncoder().encode(movie)
            return .preview(data)
        } catch {
            return .search(movie.title)
        }
    }

}
