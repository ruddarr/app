import SwiftUI

struct MovieDetailsOverview: View {
    var movie: Movie

    @EnvironmentObject var settings: AppSettings

    let imageSpan = UIDevice.current.userInterfaceIdiom == .phone ? 2 : 1

    var body: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(url: movie.remotePoster, type: .poster)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .containerRelativeFrame(.horizontal, count: 5, span: imageSpan, spacing: 0)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(movie.stateLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(settings.theme.tint)

                Text(movie.title)
                    .font(shrinkTitle ? .title : .largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .kerning(-0.5)
                    .padding(.bottom, 6)
                    .textSelection(.enabled)

                MovieDetailsSubtitle(movie: movie)

                MovieDetailsRatings(movie: movie)
            }
        }
    }

    var shrinkTitle: Bool {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return movie.title.count > 25
        }

        return false
    }
}
