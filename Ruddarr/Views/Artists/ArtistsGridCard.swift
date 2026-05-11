import SwiftUI

struct ArtistGridCard: View {
    var artist: Artist
    var model: Artist?

    @Environment(\.deviceType) private var deviceType
    @Environment(LidarrInstance.self) private var instance

    init(artist: Artist, model: Artist? = nil) {
        self.artist = artist

        if let model {
            self.artist.statistics = model.statistics
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: deviceType == .phone ? 10 : 14) {
            poster
                .frame(width: posterWidth)

            VStack(alignment: .leading) {
                Text(artist.title)
                    .lineLimit(1)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text("\(artist.albumCount) Albums")

                    if let size = artist.sizeLabel {
                        Bullet()
                        Text(size)
                    }
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(qualityProfile)
                    if let artistType = artist.artistType {
                        Bullet()
                        Text(artistType)
                    }
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                icons
            }
            .padding(.vertical, deviceType == .phone ? 8 : 10)

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity)
        .background(.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            ArtistContextMenu(artist: artist)
        } preview: {
            poster.frame(width: 300, height: 300)
        }
    }

    var poster: some View {
        CachedAsyncImage(.artist, artist.remotePoster)
            .aspectRatio(
                CGSize(width: 150, height: 150),
                contentMode: .fill
            )
    }

    var posterWidth: CGFloat {
        deviceType == .phone ? 95 : 105
    }

    var icons: some View {
        HStack {
            let iconScale: Image.Scale = deviceType == .phone ? .small : .medium

            Image(systemName: "bookmark")
                .symbolVariant(artist.monitored ? .fill : .none)
                .imageScale(iconScale)

            Group {
                if artist.percentOfTracks < 100 {
                    if artist.trackFileCount > 0 {
                        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                            .offset(y: 1)
                        Text(verbatim: "\(artist.trackFileCount)/\(artist.trackCount)")
                            .font(.caption)
                    } else if artist.monitored {
                        Image(systemName: "xmark").symbolVariant(.circle)
                    }
                }
            }
            .imageScale(iconScale)

            Spacer()

            if let status = statusIcon {
                Image(systemName: status)
                    .symbolVariant(.fill)
                    .imageScale(iconScale)
            }
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == artist.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var statusIcon: String? {
        switch artist.status {
        case .continuing: "play"
        case .ended: "stop"
        default: nil
        }
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")

    ScrollView {
        MediaGrid(items: artists, style: .cards) { artist in
            ArtistGridCard(artist: artist)
        }
        .scenePadding(.horizontal)
    }
    .withAppState()
}
