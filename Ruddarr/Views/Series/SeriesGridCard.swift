import SwiftUI

struct SeriesGridCard: View {
    var series: Series
    var model: Series?

    @Environment(\.deviceType) private var deviceType
    @Environment(SonarrInstance.self) private var instance

    init(series: Series, model: Series? = nil) {
        self.series = series

        if let model {
            self.series.statistics = model.statistics
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: deviceType == .phone ? 10 : 14) {
            poster
                .frame(width: posterWidth)

            VStack(alignment: .leading) {
                Text(series.title)
                    .lineLimit(1)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text("\(series.seasonCount) Seasons")

                    if let size = series.sizeLabel {
                        Bullet()
                        Text(size)
                    }
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(qualityProfile)
                    Bullet()
                    Text(series.seriesType.label)
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                icons
            }
            .padding(.vertical, deviceType == .phone ? 8 : 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            SeriesContextMenu(series: series)
        } preview: {
            poster.frame(width: 300, height: 450)
        }
    }

    var poster: some View {
        CachedAsyncImage(.poster, series.remotePoster, placeholder: series.title)
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var posterWidth: CGFloat {
        deviceType == .phone ? 80 : 95
    }

    var icons: some View {
        HStack {
            let iconScale: Image.Scale = deviceType == .phone ? .small : .medium

            Image(systemName: "bookmark")
                .symbolVariant(series.monitored ? .fill : .none)
                .imageScale(iconScale)

            Group {
                if series.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if series.isWaiting {
                    Image(systemName: "clock")
                } else if series.percentOfEpisodes < 100 {
                    if series.episodeFileCount > 0 {
                        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                            .offset(y: 1)
                        Text(verbatim: "\(series.episodeFileCount)/\(series.episodeCount)")
                            .font(.caption)
                    } else if series.monitored {
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
            where: { $0.id == series.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var statusIcon: String? {
        switch series.status {
        case .continuing: "play"
        case .ended: "stop"
        default: nil
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")

    ScrollView {
        MediaGrid(items: series, style: .cards) { series in
            SeriesGridCard(series: series)
        }
        .viewPadding(.horizontal)
    }
    .withAppState()
}
