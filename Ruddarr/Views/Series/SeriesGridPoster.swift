import SwiftUI

struct SeriesGridPoster: View {
    var series: Series
    var model: Series?

    init(series: Series, model: Series? = nil) {
        self.series = series

        if let model {
            self.series.statistics = model.statistics
        }
    }

    var body: some View {
        poster
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                SeriesContextMenu(series: series)
            } preview: {
                poster.frame(width: 300, height: 450)
            }
            .background(.card)
            .overlay(alignment: .bottom) {
                if series.exists {
                    SeriesPosterOverlay(series: series)
                } else {
                    previewIcons
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var poster: some View {
        CachedAsyncImage(.poster, series.remotePoster, placeholder: series.title)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var previewIcons: some View {
        MediaGridPosterOverlay {
            series.status.icon
                .foregroundStyle(.white)
                .imageScale(.gridItem)

            Spacer()
        }
    }
}

struct SeriesPosterOverlay: View {
    var series: Series

    @State private var isDownloading = false

    var body: some View {
        MediaGridPosterOverlay {
            Group {
                if isDownloading {
                    Downloading()
                } else if series.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if series.isWaiting {
                    Image(systemName: "clock")
                } else if series.percentOfEpisodes < 100 {
                    if series.episodeFileCount > 0 {
                        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                    } else if series.monitored {
                        Image(systemName: "xmark").symbolVariant(.circle)
                    }
                }
            }
            .foregroundStyle(.white)
            .imageScale(.gridItem)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(series.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(.gridItem)
        }
        .onReceive(Queue.shared.downloadingKeys) { keys in
            let value = keys.contains("s:\(series.instanceId?.uuidString ?? ""):\(series.id)")
            if value != isDownloading { isDownloading = value }
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")

    ScrollView {
        MediaGrid(items: series) { series in
            SeriesGridPoster(series: series)
        }
        .scenePadding(.horizontal)
    }
    .withAppState()
}
