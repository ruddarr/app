import SwiftUI

struct MovieGridPoster: View {
    var movie: Movie

    var body: some View {
        poster
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                MovieContextMenu(movie: movie)
            } preview: {
                poster.frame(width: 300, height: 450)
            }
            .background(.card)
            .overlay(alignment: .bottom) {
                if movie.exists {
                    posterOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var poster: some View {
        CachedAsyncImage(.poster, movie.remotePoster, placeholder: movie.title)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var posterOverlay: some View {
        HStack {
            Group {
                if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
                .foregroundStyle(.white)
                .imageScale(Self.gridIconScale())

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(Self.gridIconScale())
        }
        .font(.body)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func gridIconScale() -> Image.Scale {
        #if os(macOS)
            return .large
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return .small
            }

            return .medium
        #endif
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    ScrollView {
        MediaGrid(items: movies) { movie in
            MovieGridPoster(movie: movie)
        }
        .viewPadding(.horizontal)
    }
    .withAppState()
}
