import SwiftUI

extension MovieDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.poster, movie.remotePoster)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MediaDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, deviceType == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if movie.exists {
                    detailsState
                }

                detailsTitle
                    .padding(.bottom, 6)

                detailsSubtitle
                    .padding(.bottom, 6)

                MovieRatings(movie: movie)

                if deviceType != .phone {
                    Spacer()
                    actions
                }
            }
        }
    }

    var shrinkTitle: Bool {
        if deviceType == .phone {
            return movie.title.count > 25
        }

        return false
    }

    var detailsState: some View {
        Text(movie.stateLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(settings.theme.tint)
    }

    var detailsTitle: some View {
        Text(movie.title)
            .font(shrinkTitle ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    var detailsSubtitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(movie.yearLabel)

                if let runtime = movie.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }

                Bullet()
                Text(movie.certificationLabel)

                if deviceType != .phone, let size = movie.sizeLabel {
                    Bullet()
                    Text(size)
                }
            }

            HStack(spacing: 6) {
                Text(movie.yearLabel)

                if let runtime = movie.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
