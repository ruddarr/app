import SwiftUI

struct ArtistGridPoster: View {
    var artist: Artist
    var model: Artist?

    init(artist: Artist, model: Artist? = nil) {
        self.artist = artist

        if let model {
            self.artist.statistics = model.statistics
        }
    }

    var body: some View {
        poster
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                ArtistContextMenu(artist: artist)
            } preview: {
                poster.frame(width: 300, height: 300)
            }
            .background(.card)
            .overlay(alignment: .bottom) {
                if artist.exists {
                    ArtistsPosterOverlay(artist: artist)
                } else {
                    previewIcons
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var poster: some View {
        CachedAsyncImage(.artist, artist.remotePoster, placeholder: artist.artistName)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .aspectRatio(
                CGSize(width: 150, height: 150),
                contentMode: .fill
            )
    }

    var previewIcons: some View {
        MediaGridPosterOverlay {
            artist.status.icon
                .foregroundStyle(.white)
                .imageScale(.gridItem)

            Spacer()
        }
    }
}

struct ArtistsPosterOverlay: View {
    var artist: Artist

    var body: some View {
        MediaGridPosterOverlay {
            Group {
                if artist.percentOfTracks < 100 {
                    if artist.trackFileCount > 0 {
                        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                    } else if artist.monitored {
                        Image(systemName: "xmark").symbolVariant(.circle)
                    }
                }
            }
            .foregroundStyle(.white)
            .imageScale(.gridItem)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(artist.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(.gridItem)
        }
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")

    ScrollView {
        MediaGrid(items: artists) { artist in
            ArtistGridPoster(artist: artist)
        }
        .scenePadding(.horizontal)
    }
    .withAppState()
}
