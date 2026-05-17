import SwiftUI

extension ArtistDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.artist, artist.remotePoster)
                .aspectRatio(
                    CGSize(width: 150, height: 150),
                    contentMode: .fill
                )
                .modifier(ArtistDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.trailing, deviceType == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if artist.exists {
                    detailsState
                }

                detailsTitle
                    .padding(.bottom, 6)

                detailsSubtitle
                    .padding(.bottom, 6)

                detailsRating
                    .padding(.bottom, 6)

                if deviceType != .phone {
                    Spacer()
                    actions
                }
            }
        }
    }

    var shrinkTitle: Bool {
        if deviceType == .phone {
            return artist.title.count > 25
        }

        return false
    }

    var detailsState: some View {
        Text(artist.stateLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(settings.theme.tint)
    }

    var detailsTitle: some View {
        Text(artist.title)
            .font(shrinkTitle ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    var detailsSubtitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                if deviceType != .phone, let size = artist.sizeLabel {
//                    Bullet()
                    Text(size)
                }
            }
            HStack(spacing: 6) {
                if deviceType != .phone, let size = artist.sizeLabel {
//                    Bullet()
                    Text(size)
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    var detailsRating: some View {
        if let rating = artist.ratings?.value, rating > 0 {
            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)
                    .symbolVariant(.fill)
                    .foregroundStyle(.red)

                Text(String(format: "%.0f%%", rating * 10))
                    .lineLimit(1)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
