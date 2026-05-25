import SwiftUI

struct AlbumReleaseRow: View {
    var release: ArtistRelease
    var album: Album

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) private var instance

    var body: some View {
        VStack(alignment: .leading) {
            Text(release.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            secondRow
            thirdRow
        }
        .contentShape(Rectangle())
    }

    var secondRow: some View {
        HStack(spacing: 6) {
            Text(release.qualityLabel)

            Bullet()
            Text(release.sizeLabel)

            Bullet()
            Text(release.ageLabel)
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .font(.subheadline)
    }

    var thirdRow: some View {
        HStack(spacing: 6) {
            Text(release.typeLabel)
                .foregroundStyle(peerColor)
                .truncationMode(.head)

            Group {
                Bullet()
                Text(release.indexerLabel)
            }
            .foregroundStyle(.secondary)

            Spacer()

            releaseIcons
        }
        .lineLimit(1)
        .font(.subheadline)
    }

    var releaseIcons: some View {
        HStack(spacing: 2) {
            if release.isProper {
                Image(systemName: "p.square")
            }

            if release.isRepack {
                Image(systemName: "r.square")
            }

            if release.rejected {
                Image(systemName: "exclamationmark.square")
            }
        }
        .symbolVariant(.fill)
        .imageScale(.medium)
        .foregroundStyle(.secondary)
    }

    var peerColor: any ShapeStyle {
        if release.isUsenet {
            return .green
        }

        if release.rejections.contains(where: { $0.contains("Not enough seeders") }) {
            return .red
        }

        return switch release.seeders ?? 0 {
        case 50...: .green
        case 10..<50: .blue
        case 1..<10: .orange
        default: .red
        }
    }
}

#Preview {
    let releases: [ArtistRelease] = PreviewData.load(name: "artist-releases")
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
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
    dependencies.router.artistsPath.append(
        ArtistsPath.releases(artist.id, album.id)
    )

    return ContentView()
        .withLidarrInstance(artists: artists, albums: albums, releases: releases)
        .withAppState()
}
