import SwiftUI

struct SeriesDiscoveryView: View {
    @State private var series: [Series] = []
    @State private var isLoading = true
    @State private var error: (any Error)?

    @State private var page = 1
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var filter: DiscoveryFilter = .all
    @State private var category: TMDB.Category = .trending // NEW STATE
    @State private var libraryLookup: [Int: Series] = [:]

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

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
        .navigationTitle(category.label) // Dynamic Title
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarFilterButton
            toolbarCategoryButton // New Button
        }
        .task {
            refreshLibraryIndex()
            if series.isEmpty {
                await fetchInitial()
            }
        }
        .onChange(of: instance.series.items) {
            refreshLibraryIndex()
            series = processSeries(series)
        }
        .onChange(of: category) { // Reset and reload
            Task { await fetchInitial() }
        }
    }

    var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedSeries) { item in
                NavigationLink(value: destination(for: item)) {
                    SeriesGridPoster(series: item)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Trigger pagination when reaching near the end
                    if let index = displayedSeries.firstIndex(where: { $0.id == item.id }),
                       index >= displayedSeries.count - 6 {
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
    var displayedSeries: [Series] {
        switch filter {
        case .all: return series
        case .inLibrary: return series.filter { $0.exists }
        case .notInLibrary: return series.filter { !$0.exists }
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
                        ForEach(TMDB.sortedTVGenres, id: \.id) { genre in
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
        var dict = [Int: Series]()
        for item in instance.series.items {
            if let tmdbId = item.tmdbId {
                dict[tmdbId] = item
            }
        }
        libraryLookup = dict
    }

    func fetchInitial() async {
        guard !settings.tmdbApiKey.isEmpty else {
            isLoading = false
            return
        }

        // Reset state
        series = []
        page = 1
        hasMore = true
        isLoading = true
        error = nil

        do {
            let result = try await TMDB.fetchSeries(category, apiKey: settings.tmdbApiKey, page: page)
            self.series = processSeries(result.series)
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
            let result = try await TMDB.fetchSeries(category, apiKey: settings.tmdbApiKey, page: nextPage)
            try Task.checkCancellation()
            page = nextPage
            self.hasMore = result.hasMore
            let existingIds = Set(series.map { $0.tmdbId })
            let uniqueSeries = result.series.filter { !existingIds.contains($0.tmdbId ?? 0) }
            if !uniqueSeries.isEmpty {
                self.series.append(contentsOf: processSeries(uniqueSeries))
            }
            if !uniqueSeries.isEmpty && displayedSeries.count < 10 && hasMore {
                try? await Task.sleep(for: .milliseconds(100))
                await fetchNextPage()
            }
        } catch {
            if !(error is CancellationError) {
                dependencies.toast.show(.error(error.localizedDescription))
            }
        }
    }

    /// Enrich TMDB discovery items with Sonarr lookup so previews show full metadata
    func processSeries(_ input: [Series]) -> [Series] {
        input.map { item in
            if let local = libraryLookup[item.tmdbId ?? 0] {
                return local
            }
            return item
        }
    }

    func destination(for series: Series) -> SeriesPath {
        if series.exists {
            return .series(series.id)
        }

        do {
            let data = try JSONEncoder().encode(series)
            return .preview(data)
        } catch {
            return .search(series.title)
        }
    }
}
