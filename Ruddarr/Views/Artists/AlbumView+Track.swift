import SwiftUI

struct TrackRow: View {
    var track: AlbumTrack

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) var instance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(titleLabel)
                }

                HStack(spacing: 6) {
                    if let runtime = formatTrackRuntime(track.duration) {
                        Text(runtime)
                        Bullet()
                    }

                    Text(track.statusLabel)
                        .foregroundStyle(trackIsMissing ? .red : .secondary)

                    if let file = trackFile, let quality = file.quality {
                        Bullet()
                        Text(quality.quality.normalizedName)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.trailing)
            Spacer()
        }
        .contentShape(Rectangle())
    }

    var titleLabel: AttributedString {
        let showItalic = track.title == nil
        var attributed = AttributedString("\(track.numberLabel). ")
        attributed.foregroundColor = .secondary
        var titlePart = AttributedString(track.titleLabel)

        if showItalic {
            titlePart.inlinePresentationIntent = .emphasized
        }
        attributed += titlePart

        return attributed
    }

    var artist: Artist {
        instance.artists.byId(track.artistId) ?? Artist.void
    }

    var album: Album? {
        instance.albums.byId(track.albumId)
    }

    var trackFile: AlbumTrackFile? {
        instance.files.items.first(where: { $0.id == track.trackFileId })
    }

    var trackIsMissing: Bool {
        !track.hasFile && album?.monitored == true && artist.monitored
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
    let tracks: [AlbumTrack] = PreviewData.load(name: "album-tracks")
    let trackFiles: [AlbumTrackFile] = PreviewData.load(name: "album-track-files")
    let artist = artists.first(where: { $0.foreignArtistId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]
    let album = albums.first(where: { $0.id == 1_144 }) ?? albums[0]
    let track = tracks.first(where: { $0.albumId == album.id }) ?? tracks[0]

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
