import SwiftUI

extension MovieDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(url: movie.remotePoster, type: .poster)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MovieDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, UIDevice.current.userInterfaceIdiom == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if movie.exists {
                    detailsState
                }

                detailsTitle
                    .padding(.bottom, 6)

                detailsSubtitle
                    .padding(.bottom, 6)

                MovieRatings(movie: movie)

                if UIDevice.current.userInterfaceIdiom != .phone {
                    Spacer()
                    actions
                }
            }
        }
    }

    var shrinkTitle: Bool {
        if UIDevice.current.userInterfaceIdiom == .phone {
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
                Text(String(movie.year))

                if let runtime = movie.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }

                Bullet()
                Text(movie.certificationLabel)
            }

            HStack(spacing: 6) {
                Text(String(movie.year))

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

struct MovieDetailsPosterModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 0)
        } else {
            content.frame(width: 200, height: 300)
        }
    }
}
