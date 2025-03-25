import SwiftUI

extension SeriesDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.poster, series.remotePoster)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MediaDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, deviceType == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if series.exists {
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
            return series.title.count > 25
        }

        return false
    }

    var detailsState: some View {
        Text(series.stateLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(settings.theme.tint)
    }

    var detailsTitle: some View {
        Text(series.title)
            .font(shrinkTitle ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    var detailsSubtitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(series.yearLabel)
                Bullet()

                if let runtime = series.runtimeLabel {
                    Text(runtime)
                    Bullet()
                }

                Text(series.certificationLabel).lineLimit(1)

                if deviceType != .phone, let size = series.sizeLabel {
                    Bullet()
                    Text(size)
                }
            }

            HStack(spacing: 6) {
                Text(series.yearLabel)
                Bullet()

                if let runtime = series.runtimeLabel {
                    Text(runtime)
                }

                if deviceType != .phone, let size = series.sizeLabel {
                    Bullet()
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
        if let rating = series.ratings?.value, rating > 0 {
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
