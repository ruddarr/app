import SwiftUI

struct AlbumView: View {
    @Binding var artist: Artist
    var albumId: Album.ID
    @State var jumpToTrack: AlbumTrack.ID?

    @State private var fileSheet: MediaFile?
    @State private var eventSheet: MediaHistoryEvent?

    @State private var hasFetched: Bool = false
    @State private var dispatchingSearch: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                actions
                    .padding(.bottom)

                trackList

                if !instance.albums.history.isEmpty {
                    albumHistory
                }
            }
            .scenePadding(.horizontal)
            .viewBottomPadding()
        }
        .refreshable {
            await Task { await reload() }.value
        }
#if os(macOS)
        .padding(.vertical)
#endif
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .task {
            async let maybeFetchTracks: () = instance.tracks.maybeFetch(artist)
            async let maybeFetchFiles: () = instance.files.maybeFetch(artist)
            async let maybeFetchHistory: () =  instance.albums.fetchHistory(for: album)

            (_, _, _) = await (maybeFetchTracks, maybeFetchFiles, maybeFetchHistory)
            hasFetched = true
            maybeNavigateToTrack()
        }
        .onBecomeActive {
            await reload()
        }
        .alert(
            isPresented: instance.tracks.errorBinding,
            error: instance.tracks.error
        ) { _ in
            Button("OK") { instance.tracks.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert(
            isPresented: instance.files.errorBinding,
            error: instance.files.error
        ) { _ in
            Button("OK") { instance.files.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete Files", role: .destructive) {
                Task { await deleteAlbum() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase all track files of this album.")
        }.tint(nil)
    }

    var album: Album {
        let fallback = Album.void
        return instance.albums.byId(albumId) ?? fallback
    }

    var tracks: [AlbumTrack] {
        instance.tracks.items
            .filter { $0.albumId == albumId }
            .sorted { $0.absoluteTrackNumber < $1.absoluteTrackNumber }
    }

    var albumFiles: [AlbumTrackFile] {
        tracks.filter {
            $0.hasFile
        }.compactMap { track in
            instance.files.items.first { file in
                file.id == track.trackFileId
            }
        }
    }

    var posterWidth: CGFloat {
        deviceType == .phone ? 300 : 500
    }

    var header: some View {
        VStack(alignment: .center, spacing: 6) {
            CachedAsyncImage(.artist, album.albumCover, placeholder: album.title)
                .frame(width: posterWidth, height: posterWidth)
                .scaledToFill()

            Text(album.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .offset(y: 2)

            HStack(spacing: 6) {
                if let runtime = formatTrackRuntime(album.duration) {
                    Text(runtime)
                    Bullet()
                }

                if let released = album.releaseDate {
                    Text(released.formatted(date: .abbreviated, time: .omitted))
                }

                if album.percentOfTracks > 0 {
                    if let sizeLabel = album.sizeLabel {
                        Bullet()
                        Text(sizeLabel)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var runtime: Int? {
        let items = tracks.map { $0.duration }.filter { $0 > 0 }
        guard !items.isEmpty else { return nil }
        return items.sorted(by: <)[items.count / 2]
    }

    var actions: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 24) {
                Button {
                    Task { await dispatchSearch() }
                } label: {
                    ButtonLabel(
                        text: String(localized: "Automatic"),
                        icon: "magnifyingglass",
                        isLoading: dispatchingSearch
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.buttonTint)
                .allowsHitTesting(!instance.albums.isWorking)

                NavigationLink(
                    value: ArtistsPath.releases(artist.id, albumId)
                ) {
                    ButtonLabel(text: String(localized: "Interactive"), icon: "person.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.buttonTint)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 450)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var trackList: some View {
        Section {
            if !hasFetched && (instance.tracks.isFetching || instance.files.isFetching) {
                HStack {
                    Spacer()
                    ProgressView().tint(.secondary)
                    Spacer()
                }
            } else {
                let mediums = Set(tracks.map(\.mediumNumber)).sorted()

                ForEach(mediums, id: \.self) { medium in
                    let mediumTracks = tracks.filter { $0.albumId == albumId && $0.mediumNumber == medium }

                    if mediums.count > 1 {
                        Text(String(localized: "Disc \(medium)"))
                            .font(.title3.bold())
                            .padding(.vertical, 6)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(mediumTracks) { track in
                            NavigationLink(
                                value: ArtistsPath.track(track.albumId, track.id)
                            ) {
                                TrackRow(track: track)
                                    .environment(instance)
                                    .environmentObject(settings)
                            }
                            .buttonStyle(.plain)

                            if track != mediumTracks.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Tracks").font(.title2.bold()).padding(.bottom, 6)
        }
    }

    var albumHistory: some View {
        Section {
            ForEach(instance.albums.history.filter { $0.albumId == album.id }) { event in
                MediaHistoryItem(event: event)
                    .padding(.bottom, 4)
                    .onTapGesture { eventSheet = event }
            }
        } header: {
            Text("History")
                .font(.title2.bold())
                .padding(.bottom, 6)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
                .presentationBackground(.sheetBackground)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: .constant(album.monitored))
            }
            .allowsHitTesting(!instance.artists.isWorking)
            .disabled(!artist.monitored)
            .popoverTip(SeriesMonitoringTip(artist.monitored))
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await reload() }
                }

                Button("Automatic Search", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }

                Section {
                    deleteSeasonButton
                }
            } label: {
                ToolbarActionButton()
            }
            .menuIndicator(.hidden)
        }
    }

    var deleteSeasonButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }.disabled(albumFiles.isEmpty)
    }
}

extension AlbumView {
    func toggleMonitor() async {
        guard let index = instance.albums.items.firstIndex(where: { $0.id == albumId }) else {
            return
        }

        var updatingAlbum = instance.albums.items[index]

        updatingAlbum.monitored.toggle()

        guard await instance.albums.push(updatingAlbum) else {
            return
        }

        dependencies.toast.show(
            album.monitored ? .monitored : .unmonitored
        )

        await instance.tracks.fetch(artist)
    }

    func reload() async {
        _ = await instance.artists.get(artist)
        await instance.tracks.fetch(artist)
        await instance.files.fetch(artist)
    }

    func dispatchSearch() async {
        defer { dispatchingSearch = false }
        dispatchingSearch = true

        guard await instance.artists.command(
            .albumSearch(artist.id, album: album.id)
        ) else {
            return
        }

        dependencies.toast.show(.albumSearchQueued)

        Telemetry.record(.albumSearchDispatched)
        maybeAskForReview()
    }

    func maybeNavigateToTrack() {
        guard let id = jumpToTrack else {
            return
        }

        guard let track = tracks.first(where: { $0.id == id }) else {
            return
        }

        jumpToTrack = nil

        dependencies.router.artistsPath.append(
            ArtistsPath.track(artist.id, track.id)
        )
    }

    func deleteAlbum() async {
        guard !albumFiles.isEmpty else { return }

        guard await instance.files.delete(albumFiles) else { return }

        _ = await instance.albums.monitor([albumId], false)

        dependencies.toast.show(.seasonDeleted)
        await reload()
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
    let tracks: [AlbumTrack] = PreviewData.load(name: "album-tracks")
    let trackFiles: [AlbumTrackFile] = PreviewData.load(name: "album-track-files")
    let artist = artists.first(where: { $0.foreignArtistId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]
    let album = albums.first(where: { $0.id == 1_144 }) ?? albums[0]

    dependencies.api = .mock
    dependencies.router.selectedTab = .artists

    dependencies.router.artistsPath.append(
        ArtistsPath.artist(artist.id)
    )

    dependencies.router.artistsPath.append(
        ArtistsPath.album(artist.id, album.id)
    )

    return ContentView()
        .withLidarrInstance(artists: artists, albums: albums, tracks: tracks, trackFiles: trackFiles)
        .withAppState()
}
