import SwiftUI

struct SeriesGridItem: View {
    var series: Series

    var body: some View {
        VStack {
            poster
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu {
                    SeriesContextMenu(series: series)
                } preview: {
                    poster.frame(width: 300, height: 450)
                }
                .background(.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Group {
                Text(series.title).font(.footnote).fontWeight(.medium)
                HStack(spacing: 4) {
                    Group {
                        if series.isDownloaded {
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
                    }.font(.caption)
                    Text(series.monitored ? "Monitored" : "Unmonitored").font(.footnote)
                }.foregroundStyle(.secondary).opacity(0.8)
            }.frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
        }
    }

    var poster: some View {
        CachedAsyncImage(.poster, series.remotePoster, placeholder: series.title)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var posterOverlay: some View {
        HStack {
            if series.exists {
                posterIcons
            } else {
                posterIconsPreview
            }
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

    @ViewBuilder
    var posterIcons: some View {
        Group {
            if series.isDownloaded {
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
        .imageScale(MovieGridItem.gridIconScale())

        Spacer()

        Image(systemName: "bookmark")
            .symbolVariant(series.monitored ? .fill : .none)
            .foregroundStyle(.white)
            .imageScale(MovieGridItem.gridIconScale())
    }

    var posterIconsPreview: some View {
        Group {
            series.status.icon
                .foregroundStyle(.white)
                .imageScale(MovieGridItem.gridIconScale())

            Spacer()
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
        .sorted { $0.year > $1.year }

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
    ]

    return ScrollView {
        LazyVGrid(columns: gridItemLayout, spacing: 12) {
            ForEach(series) { series in
                SeriesGridItem(series: series)
            }
        }
        .padding(.top, 0)
        .viewPadding(.horizontal)
    }
    .withAppState()
}
