import SwiftUI

struct SeriesGridItem: View {
    var series: Series

    var body: some View {
        ZStack {
            poster
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            SeriesContextMenu(series: series)
        } preview: {
            poster.frame(width: 300, height: 450)
        }
        .background(.secondarySystemBackground)
        .overlay(alignment: .bottom) {
            if series.exists {
                posterOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            Group {
                // TODO: needs work
                if series.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if series.isWaiting {
                    Image(systemName: "clock")
                } else if series.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }.foregroundStyle(.white)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(series.monitored ? .fill : .none)
                .foregroundStyle(.white)
        }
        .font(.body)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
