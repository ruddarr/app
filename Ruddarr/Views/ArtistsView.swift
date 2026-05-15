import SwiftUI

enum ArtistsPath: Hashable {
    case search(String = "")
    case preview(Data?)
    case artist(Artist.ID)
    case edit(Artist.ID)
    case releases(Artist.ID, Album.ID)
}

struct ArtistsView: View {
    @AppStorage("artistSort", store: dependencies.store) var sort: ArtistSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) var instance

    @State private var scrollView: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: API.Error?
    @State private var alertPresented = false

    @State private var lastFetch: Date = .distantPast

    @Environment(\.deviceType) private var deviceType

    var body: some View {
        // swiftlint:disable:next closure_body_length
        NavigationStack(path: dependencies.$router.artistsPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Lidarr")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            mediaGrid

                            if presentSearchSuggestion {
                                ArtistsSearchSuggestion(query: $searchQuery, sort: $sort)
                            }
                        }
                        .onAppear { scrollView = proxy }
                    }
                    .task {
                        guard !instance.isVoid else { return }
                        await fetchArtistsThrottled()
                    }
                    .refreshable {
                        await Task { await fetchArtistsWithAlert() }.value
                    }
                    .onBecomeActive(perform: becameActive)
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ArtistsPath.self) { destination(for: $0) }
            .onAppear {
                // if a deeplink set an instance, try to switch to it
                maybeSwitchToInstance()

                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if instance.isVoid, let first = settings.lidarrInstances.first {
                    settings.lidarrInstanceId = first.id
                    changeInstance()
                }
            }
            .onReceive(dependencies.quickActions.artistPublisher, perform: navigateToArtist)
            .toolbar {
                toolbarViewOptions
                toolbarSearchButton

                if settings.lidarrInstances.count > 1 {
                    if deviceType == .phone { toolbarInstancePicker }
                    if deviceType == .pad { bottomBarInstancePicker }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(text: $searchQuery, isPresented: $searchPresented, placement: .drawerOrToolbar)
            .autocorrectionDisabled(true)
            .onChange(of: settings.lidarrInstanceId, changeInstance)
            .onChange(of: sort.option, updateSortDirection)
            .onChange(of: sort, handleFilterChange)
            .onChange(of: searchQuery, handleQueryChange)
            .onChange(of: instance.artists.items, updateDisplayedArtists)
            .alert(isPresented: $alertPresented, error: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .tint(nil)
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if hasNoSearchResults {
                    NoArtistsSearchResults(query: $searchQuery, sort: $sort)
                } else if isLoadingArtist {
                    Loading()
                } else if hasNoMatchingResults {
                    NoMatchingArtists(sort: $sort)
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
    }

    @ViewBuilder
    func destination(for path: ArtistsPath) -> some View {
        switch path {
        case .search(let query):
            ArtistSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            if let data, let artist = try? JSONDecoder().decode(Artist.self, from: data) {
                ArtistPreviewView(artist: artist)
                    .environment(instance)
                    .environmentObject(settings)
            }
        case .artist(let id):
            ArtistDetailView(
                artist: instance.artists.byId(id),
                releases: instance.albums.byArtistId(id)
            )
            .environment(instance)
            .environmentObject(settings)
        case .edit(let id):
            ArtistEditView(artist: instance.artists.byId(id))
                .environment(instance)
        case .releases(let artistId, let releaseId):
            ArtistReleaseView(
                artist: instance.artists.byId(artistId),
                release: instance.albums.byId(releaseId)
            )
            .environment(instance)
            .environmentObject(settings)
        }
    }

    var mediaGrid: some View {
        MediaGrid(
            items: instance.artists.cachedItems,
            style: settings.grid
        ) { artist in
            NavigationLink(value: ArtistsPath.artist(artist.id)) {
                switch settings.grid {
                case .posters:
                    ArtistGridPoster(artist: artist)
                case .cards:
                    ArtistGridCard(artist: artist)
                }
            }
            .buttonStyle(.plain)
            .id(artist.id)
        }
        .viewBottomPadding()
        .scenePadding(.horizontal)
#if os(iOS)
        .padding(.top, searchPresented ? 7 : 0)
#elseif os(macOS)
        .padding(.vertical)
#endif
    }

    var notConnectedToInternet: Bool {
        if !instance.artists.cachedItems.isEmpty { return false }
        if case .notConnectedToInternet = error { return true }
        return false
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && !instance.isVoid && instance.artists.cachedItems.isEmpty
    }

    var hasNoMatchingResults: Bool {
        instance.artists.cachedItems.isEmpty && instance.artists.itemsCount > 0
    }

    var presentSearchSuggestion: Bool {
        searchPresented && !instance.artists.cachedItems.isEmpty
    }

    var isLoadingArtist: Bool {
        instance.artists.isWorking && instance.artists.cachedItems.isEmpty
    }

    var initialLoadingFailed: Bool {
        guard instance.artists.itemsCount == 0 else { return false }
        return instance.artists.error != nil
    }

    @ViewBuilder
    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("Connection Failure", systemImage: "exclamationmark.triangle")
        } description: {
            Text(instance.artists.error?.recoverySuggestionFallback ?? "")
        } actions: {
            Button("Retry") {
                Task { await fetchArtistsWithAlert(ignoreOffline: true) }
            }
        }
    }

    func updateSortDirection() {
        switch sort.option {
        case .byName:
            sort.isAscending = true
        default:
            sort.isAscending = false
        }
    }

    func updateDisplayedArtists() {
        instance.artists.updateCachedItems(sort, searchQuery)
    }

    func fetchArtistsWithMetadata() {
        Task { @MainActor in
            _ = await instance.artists.fetch()
            updateDisplayedArtists()

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

    func fetchArtistsThrottled() async {
        guard Date.now.timeIntervalSince(lastFetch) >= 15 else { return }
        _ = await instance.artists.fetch()
        updateDisplayedArtists()
        lastFetch = .now
    }

    func fetchArtistsWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.artists.fetch()
        updateDisplayedArtists()

        if let apiError = instance.artists.error {
            error = apiError

            if case .notConnectedToInternet = apiError, ignoreOffline {
                return
            }

            alertPresented = true
        }
    }

    func handleFilterChange() {
        scrollToTop()
        updateDisplayedArtists()
    }

    func handleQueryChange() {
        if let mbId = extractMbId(searchQuery) {
            searchQuery = "mb:\(mbId)"
            return
        }

        scrollToTop()
        updateDisplayedArtists()
    }

    func becameActive() {
        guard dependencies.router.artistsPath.isEmpty else { return }
        fetchArtistsWithMetadata()
    }

    func scrollToTop() {
        withAnimation(.smooth) {
            scrollView?.scrollTo(
                instance.artists.cachedItems.first?.id
            )
        }
    }

    func maybeSwitchToInstance() {
        guard let idOrName = dependencies.router.switchToLidarrInstance else { return }
        guard let switchTo = settings.instanceBy(idOrName) else { return }

        if switchTo.id != instance.id {
            dependencies.router.switchToLidarrInstance = nil
            settings.lidarrInstanceId = switchTo.id
            changeInstance()
        }
    }

    func navigateToArtist(_ artistId: Artist.ID, _ albumId: Album.ID?) {
        dependencies.quickActions.clearTimer()
        maybeSwitchToInstance()

        let startTime = Date()

        func scheduleNextRun(
            time: DispatchTime,
            _ artistId: Artist.ID,
            _ albumId: Album.ID?
        ) {
            DispatchQueue.main.asyncAfter(deadline: time) {
                if let artist = instance.artists.items.first(where: { $0.id == artistId }) {
                    dependencies.router.artistsPath = .init([
                        ArtistsPath.artist(artist.id)
                    ])

                    if let albumId {
                        dependencies.router.artistsPath.append(
                            ArtistsPath.releases(artistId, albumId)
                        )
                    }

                    return
                }

                if Date().timeIntervalSince(startTime) < 10 {
                    scheduleNextRun(time: DispatchTime.now() + 0.1, artistId, albumId)
                }
            }
        }

        scheduleNextRun(time: DispatchTime.now(), artistId, albumId)
    }
}

#Preview("Offline") {
    dependencies.api.fetchArtists = { _ in
        throw API.Error.notConnectedToInternet
    }

    dependencies.router.selectedTab = .artists

    return ContentView()
        .withAppState()
}

#Preview {
    dependencies.router.selectedTab = .artists

    return ContentView()
        .withAppState()
}
