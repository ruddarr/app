import SwiftUI

extension SeriesDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.poster, series.remotePoster)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MovieDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, UIDevice.current.userInterfaceIdiom == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if series.exists {
                    detailsState
                }

                detailsTitle
                    .padding(.bottom, 6)

                detailsSubtitle
                    .padding(.bottom, 6)

                // TODO: ratings...
                // MovieRatings(series: series)

                if UIDevice.current.userInterfaceIdiom != .phone {
                    Spacer()
                    actions
                }
            }
        }
    }

    var shrinkTitle: Bool {
        if UIDevice.current.userInterfaceIdiom == .phone {
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
                Text(String(series.year))
                // TODO: end year...  2009-2011

                if let runtime = series.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }

                Bullet()
                Text(series.certificationLabel)
            }

            HStack(spacing: 6) {
                Text(String(series.year))

                if let runtime = series.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
