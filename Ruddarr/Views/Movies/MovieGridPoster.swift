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
                    MoviePosterOverlay(movie: movie)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var poster: some View {
        CachedAsyncImage(.poster, movie.remotePoster, placeholder: movie.title)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }
}

struct MoviePosterOverlay: View {
    var movie: Movie

    @State private var queueStatus: QueueItemStatus?

    var body: some View {
        MediaGridPosterOverlay {
            Group {
                if let queueStatus {
                    QueueStatusIcon(status: queueStatus, color: .white, tint: .white)
                } else if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .foregroundStyle(.white)
            .imageScale(.gridItem)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(.gridItem)
        }
        .tracksQueueStatus(movie.queueKey, into: $queueStatus)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    ScrollView {
        MediaGrid(items: movies) { movie in
            MovieGridPoster(movie: movie)
        }
        .scenePadding(.horizontal)
    }
    .withAppState()
}
