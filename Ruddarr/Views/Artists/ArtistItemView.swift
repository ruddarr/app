import SwiftUI

struct ArtistDetailView: View {
    @Binding var artist: Artist
    @Binding var releases: [Album]

    @EnvironmentObject var settings: AppSettings

    @Environment(\.deviceType) private var deviceType
    @Environment(LidarrInstance.self) private var instance

    @State private var showEditForm = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            ArtistDetails(artist: $artist, albums: $releases)
                .padding(.top)
                .scenePadding(.horizontal)
                .environmentObject(settings)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .onAppear {
            maybeReloadRepeatedly()
        }
        .task {
            await instance.albums.maybeFetch(artist)
            await instance.tracks.maybeFetch(artist)
        }
        .onBecomeActive {
            await reload()
        }
        .alert(
            isPresented: instance.artists.errorBinding,
            error: instance.artists.error
        ) { _ in
            Button("OK") { instance.artists.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .sheet(isPresented: $showDeleteConfirmation) {
            MediaDeleteSheet(label: "Delete Artist") { exclude, delete in
                Task {
                    await deleteArtist(exclude: exclude, delete: delete)
                    showDeleteConfirmation = false
                }
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .fraction(0.33) : .medium])
            .presentationBackground(.sheetBackground)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: $artist.monitored)
            }
            .allowsHitTesting(!instance.artists.isWorking)
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                    searchMonitored
                }

                Section {
                    editAction
                    deleteArtistButton
                }

                // Lower than other pages due to the increased link counts
                Section {
                    ArtistLinks(artist: artist)
                }
            } label: {
                ToolbarActionButton()
            }
            .tint(.primary)
            .menuIndicator(.hidden)
            #if os(macOS)
                .sheet(isPresented: $showEditForm) {
                    ArtistEditView(artist: $artist)
                        .environment(instance)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showEditForm = false }
                            }
                        }
                }
            #endif
        }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        #if os(macOS)
            Button("Edit", systemImage: "pencil") {
                showEditForm = true
            }
        #else
            NavigationLink(
                value: ArtistsPath.edit(artist.id)
            ) {
                Label("Edit", systemImage: "pencil")
            }
        #endif
    }

    var searchMonitored: some View {
        Button("Search Monitored", systemImage: "magnifyingglass") {
            Task { await dispatchSearch() }
        }
        .disabled(!artist.monitored)
    }

    var deleteArtistButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }.tint(.red)
    }
}

extension ArtistDetailView {
    func toggleMonitor() async {
        artist.monitored.toggle()

        guard await instance.artists.update(artist) else {
            return
        }

        dependencies.toast.show(artist.monitored ? .monitored : .unmonitored)
    }

    func reload() async {
        _ = await instance.artists.get(artist)
        _ = await instance.albums.fetch(artist)
        _ = await instance.tracks.fetch(artist)
    }

    func refresh() async {
        guard await instance.artists.command(.refreshArtist(artist.id)) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.artists.get(artist) }
        }
    }

    func dispatchSearch() async {
        guard await instance.artists.command(
            .artistSearch(artist.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.artistSearchDispatched)
        maybeAskForReview()
    }

    func deleteArtist(exclude: Bool, delete: Bool) async {
        _ = await instance.artists.delete(artist, addExclusion: exclude, deleteFiles: delete)

        if !dependencies.router.artistsPath.isEmpty {
            dependencies.router.artistsPath.removeLast()
        }

        dependencies.toast.show(.artistDeleted)
    }

    // This is an annoying "hack" because Lidarr takes a couple of seconds
    // after adding a new artist before it updates its monitoring values.
    func maybeReloadRepeatedly() {
        if abs(artist.added.timeIntervalSinceNow) > 15 {
            return
        }

        Task {
            for _ in 0..<6 {
                _ = await instance.artists.get(artist, silent: true)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
    let item = artists.first(where: { $0.foreignArtistId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]

    dependencies.router.selectedTab = .artists

    dependencies.router.artistsPath.append(
        ArtistsPath.artist(item.id)
    )

    return ContentView()
        .withLidarrInstance(artists: artists, albums: albums)
        .withAppState()
}
