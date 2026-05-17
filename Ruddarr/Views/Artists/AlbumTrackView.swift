import SwiftUI

struct AlbumTrackView: View {
    @Binding var artist: Artist
    var trackId: AlbumTrackFile.ID

    @State private var track: AlbumTrack = AlbumTrack.void
    @State private var trackFile: AlbumTrackFile?

    @State private var fileSheet: AlbumTrackFile?
    @State private var eventSheet: MediaHistoryEvent?

    @State private var dispatchingSearch: Bool = false
    @State private var descriptionTruncated = true
    @State private var showDeleteConfirmation = false

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    var startOfToday = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                details
                    .padding(.bottom)

                if trackFile != nil {
                    file
                }
            }
            .onAppear(perform: setTrackState)
            .padding(.vertical)
            .scenePadding(.horizontal)
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(track.statusLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(settings.theme.tint)

            Text(track.titleLabel)
                .font(.largeTitle.bold())
                .italic(track.title == nil)
                .kerning(-0.5)

            HStack(spacing: 6) {
                if let runtime = formatTrackRuntime(track.duration) {
                    Text(runtime)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            if !artist.genres.isEmpty {
                MediaDetailsRow(
                    String(localized: "Genre", comment: "Genres of the movie/series/artist"),
                    value: artist.genreLabel
                )
            }

            if track.hasFile {
                Group {
                    MediaDetailsRow(String(localized: "Audio"), value: mediaDetailsAudioQuality(trackFile))
                }.onTapGesture {
                    fileSheet = trackFile
                }
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if trackFile != nil {
                Menu {
                    Section {
                        deleteFileButton
                    }
                } label: {
                    ToolbarActionButton()
                }
                .tint(.primary)
                .menuIndicator(.hidden)
            }
        }
    }

    var deleteFileButton: some View {
        Button("Delete File", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }.tint(.red)
    }

    var file: some View {
        Section {
            if let file = trackFile {
                LabeledGroupBox {
                    HStack(spacing: 6) {
                        if let quality = file.quality {
                            Text(quality.quality.label)
                            Bullet()
                        }
                        Text(file.sizeLabel)
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } label: {
                    Text(file.filenameLabel)
                }
                .onTapGesture { fileSheet = file }
                .contextMenu { deleteFileButton }
                .popoverTip(DeleteFileTip())
                .padding(.bottom)
            }
        } header: {
            Text("Files").font(.title2.bold()).padding(.bottom, 6)
        }
        .sheet(item: $fileSheet) { file in
            AudioMediaFileSheet(file: file, runtime: track.runtime)
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(.sheetBackground)
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete File", role: .destructive) {
                Task { await deleteTrack() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase the track file.")
        }.tint(nil)
    }
}

extension AlbumTrackView {
    func setTrackState() {
        if let track = instance.tracks.items.first(where: { $0.id == trackId }) {
            self.track = track
            self.trackFile = instance.files.items.first(where: { $0.id == track.trackFileId })
        }
    }

    func reload() async {
        _ = await instance.tracks.fetch(artist)
    }

    func deleteTrack() async {
        guard let trackFile else { return }

        if await instance.files.delete(trackFile) {
            dependencies.toast.show(.fileDeleted)
            await reload()
        }
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
    let tracks: [AlbumTrack] = PreviewData.load(name: "album-tracks")
    let trackFiles: [AlbumTrackFile] = PreviewData.load(name: "album-track-files")
    let artist = artists.first(where: { $0.foreignArtistId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]
    let album = albums.first(where: { $0.id == 1_144 }) ?? albums[0]
    let track = tracks.first(where: { $0.albumId == 1_144 }) ?? tracks[0]

    dependencies.router.selectedTab = .artists

    dependencies.router.artistsPath.append(
        ArtistsPath.artist(artist.id)
    )

    dependencies.router.artistsPath.append(
        ArtistsPath.album(artist.id, album.id)
    )

    dependencies.router.artistsPath.append(
        ArtistsPath.track(artist.id, track.id)
    )

    return ContentView()
        .withLidarrInstance(artists: artists, albums: albums, tracks: tracks, trackFiles: trackFiles)
        .withAppState()
}
