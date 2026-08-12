import SwiftUI
import Nuke

extension SeriesDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.poster, series.remotePoster, priority: .veryHigh)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MediaDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .posterQuickLook(series.remotePoster, named: series.posterFilename)
                .padding(.trailing, deviceType == .phone ? 8 : 16)

            VStack(alignment: .leading, spacing: 0) {
                if series.exists {
                    detailsState
                }

                detailsTitle
                    .padding(.bottom, 6)

                detailsSubtitle
                    .padding(.bottom, 6)

                detailsRating
                    .padding(.bottom, 6)

                if deviceType != .phone {
                    Spacer()
                    actions
                }
            }
        }
    }

    var detailsState: some View {
        Text(stateLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .shimmering(active: queueStatus != nil, color: settings.theme.tint)
    }

    var stateLabel: String {
        if let label = queueStatus?.label { return label }
        return series.stateLabel
    }

    var queueStatus: QueueItemStatus? {
        queue.queueStatus(series, instanceId: instance.id)
    }

    var detailsTitle: some View {
        Text(series.title)
            .font(deviceType == .phone && series.title.count > 25 ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    var detailsSubtitle: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(series.yearLabel)
                Bullet()

                if let runtime = series.runtimeLabel {
                    Text(runtime)
                    Bullet()
                }

                Text(series.certificationLabel).lineLimit(1)

                if deviceType != .phone, let size = series.sizeLabel {
                    Bullet()
                    Text(size)
                }
            }

            HStack(spacing: 6) {
                Text(series.yearLabel)
                Bullet()

                if let runtime = series.runtimeLabel {
                    Text(runtime)
                }

                if deviceType != .phone, let size = series.sizeLabel {
                    Bullet()
                    Text(size)
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    var detailsRating: some View {
        if let rating = series.ratings?.value, rating > 0 {
            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)
                    .symbolVariant(.fill)
                    .foregroundStyle(.red)

                Text((rating * 10).formatted(.percentageRating))
                    .lineLimit(1)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
