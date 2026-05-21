import SwiftUI

struct AlbumCard: View {
    @Binding var artist: Artist
    @Binding var album: Album
    var albums: [Album] = []

    @State private var isWorking: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(LidarrInstance.self) private var instance

    var body: some View {
        LabeledGroupBox {
            HStack(spacing: 12) {
                Text(album.title)
                    .fontWeight(.medium)

                if let progress = album.progressLabel {
                    Text(progress)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await toggle()
                    }
                } label: {
                    if isWorking {
                        ButtonProgressView(tint: .secondary).offset(x: 1.5)
                    } else {
                        Image(systemName: "bookmark")
                            .symbolVariant(album.monitored ? .fill : .none)
                            .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
                    }
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().padding(18))
                .allowsHitTesting(!instance.albums.isWorking)
            }
        }
    }

    func toggle() async {
        guard !isWorking else { return }

        album.monitored.toggle()

        isWorking = true

        guard await instance.albums.push(album) else {
            isWorking = false
            return
        }

        isWorking = false

        dependencies.toast.show(
            album.monitored ? .monitored : .unmonitored
        )

        await instance.albums.fetch(artist)
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let albums: [Album] = PreviewData.load(name: "artist-albums")
    let artist = artists.first(where: { $0.foreignArtistId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]
    let album = albums.first(where: { $0.id == 1_144 }) ?? albums[0]
    let artistBinding = Binding<Artist>(get: { artist }, set: { _ in })
    let albumBinding = Binding<Album>(get: { album }, set: { _ in })

    VStack {
        Section {
            LazyVStack(alignment: .leading, spacing: 12) {
                AlbumCard(artist: artistBinding, album: albumBinding)
                AlbumCard(artist: artistBinding, album: albumBinding)
                AlbumCard(artist: artistBinding, album: albumBinding)
            }
        } header: {
            Text("Albums")
                .font(.title2.bold())
                .padding(.bottom, 6)
        }
        .padding(.horizontal)
    }
    .withLidarrInstance(artists: artists, albums: albums)
    .withAppState()
}
