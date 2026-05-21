import SwiftUI
import TelemetryDeck

struct ArtistDetails: View {
    @Binding var artist: Artist
    @Binding var albums: [Album]

    @State private var dispatchingSearch: Bool = false
    @State private var descriptionTruncated = true

    @State private var expandedAlbumTypes: Set<String> = []

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) var instance

    @Environment(\.deviceType) var deviceType

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.bottom)

            details
                .padding(.bottom)

            if hasDescription {
                description
                    .padding(.bottom)
            }

            if deviceType == .phone && !artist.exists {
                actions
                    .padding(.bottom)
            }

            if artist.exists {
                if !albums.isEmpty {
                    albumSection
                }
            }
        }
    }

    var hasDescription: Bool {
        !(artist.overview ?? "").trimmed().isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(artist.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            if let blurb = artist.disambiguation {
                if !blurb.isEmpty {
                    MediaDetailsRow(String(localized: "Disambiguation"), value: "\(blurb)")
                }
            }

            if let type = artist.artistType {
                MediaDetailsRow(String(localized: "Artist Type"), value: "\(type)")
            }

            MediaDetailsRow(String(localized: "Status"), value: "\(artist.status.label)")

            if !artist.exists && artist.albumCount != 0 {
                MediaDetailsRow(String(localized: "Releases"), value: artist.albumCount.formatted())
            }

            if !artist.genres.isEmpty {
                MediaDetailsRow(String(localized: "Genre"), value: artist.genreLabel)
            }
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            if artist.exists {
                artistActions
            } else {
                previewActions
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var artistActions: some View {
        Group {
            Button {
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(
                    text: String(localized: "Search Monitored"),
                    icon: "magnifyingglass",
                    isLoading: dispatchingSearch
                )
                .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.buttonTint)
            .allowsHitTesting(!instance.artists.isWorking)
            .onAppear(perform: triggerTipIfJustAdded)
            .popoverTip(NoAutomaticSearchTip())

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var previewActions: some View {
        Group {
            Menu {
                ArtistLinks(artist: artist)
            } label: {
                ButtonLabel(text: String(localized: "Open In..."), icon: "arrow.up.right.square")
                    .modifier(MediaPreviewActionModifier())
                    .modifier(MacMenuButtonLabelModifier())
            }
#if os(macOS)
            .buttonStyle(.plain)
#else
            .buttonStyle(.bordered)
#endif
            .tint(.buttonTint)

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == artist.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var metadataProfile: String {
        instance.metadataProfiles.first(
            where: { $0.id == artist.metadataProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    @ViewBuilder
    var albumSection: some View {
        let albumMap = Dictionary(grouping: albums, by: { $0.albumType ?? String(localized: "Unknown Album Type", comment: "Unknown album type section label") })

        ForEach(albumMap.keys.sorted(), id: \.self) { key in
            if let releases = albumMap[key]?.sorted(by: { $0.releaseDate ?? Date.distantPast > $1.releaseDate ?? Date.distantPast }) {
                ArtistAlbumCollection(artist: $artist, albums: releases, albumType: key)
            }
        }
    }

    func triggerTipIfJustAdded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if artist.added.timeIntervalSinceNow > -30 {
                Task {
                    await NoAutomaticSearchTip.mediaAdded.donate()
                }
            }
        }
    }

    func dispatchSearch() async {
        defer { dispatchingSearch = false }
        dispatchingSearch = true

        guard await instance.artists.command(
            .artistSearch(artist.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        Telemetry.record(.artistSearchDispatched)
        maybeAskForReview()
    }
}

struct ArtistAlbumCollection: View {
    @Binding var artist: Artist
    @State var albums: [Album]
    var albumType: String

    @State var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header with chevron and tap to expand/collapse
            HStack {
                Text(String(localized: "\(albumType)s", comment: "Album type collective name"))
                    .font(.title2.bold())
                    .padding(.bottom, 6)
                Spacer()
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? -90 : 0))
                    .animation(.snappy(duration: 0.25), value: expanded)
                    .padding(.trailing, 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.25)) {
                    expanded.toggle()
                }
            }
            .padding(.vertical, 6)

            if expanded {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(albums) { album in
                        if let idx = albums.firstIndex(where: { $0.id == album.id }) {
                            NavigationLink(value: ArtistsPath.album(artist.id, album.id)) {
                                AlbumCard(artist: $artist, album: $albums[idx])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale),
                        removal: .opacity.combined(with: .scale)
                    )
                )
            }
        }
        .animation(.snappy(duration: 0.25), value: expanded)
    }
}

struct ArtistDetailsPreview: View {
    let artists: [Artist]
    let albums: [Album]
    let tracks: [AlbumTrack]
    @State var tracksCollection: [AlbumTrack]
    @State var albumsCollection: [Album]
    @State var item: Artist

    init(_ file: String) {
        let artists: [Artist] = PreviewData.load(name: file)
        let albums: [Album] = PreviewData.load(name: "artist-albums")
        let tracks: [AlbumTrack] = PreviewData.load(name: "artist-tracks")
        self.artists = artists
        self.albums = albums
        self.tracks = tracks
        self._item = State(initialValue: artists.first(where: { $0.foreignArtistId == "00d0f0fa-a48c-416d-b4ff-25a290ce82d8" }) ?? artists[0])
        self._albumsCollection = State(initialValue: albums)
        self._tracksCollection = State(initialValue: tracks)
    }

    var body: some View {
        ArtistDetailView(artist: $item, releases: $albumsCollection)
            .withLidarrInstance(artists: artists, albums: albums, tracks: tracks)
            .withAppState()
    }
}

#Preview("Preview") {
    dependencies.api = .mock

    return ArtistDetailsPreview("artist-lookup")
}

#Preview {
    dependencies.api = .mock

    return ArtistDetailsPreview("artists")
}
