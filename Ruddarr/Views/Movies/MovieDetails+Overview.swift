import SwiftUI
import Nuke

extension MovieDetails {
    var header: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(.poster, movie.remotePoster, priority: .veryHigh)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .modifier(MediaDetailsPosterModifier())
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .posterQuickLook(movie.remotePoster, named: movie.posterFilename)
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

                if !isCompactPhone {
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
        return movie.stateLabel
    }

    var queueStatus: QueueItemStatus? {
        queue.queueStatus(movie, instanceId: instance.id)
    }

    var detailsTitle: some View {
        Text(movie.title)
            .font(deviceType == .phone && movie.title.count > 25 ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    var detailsSubtitle: some View {
        ViewThatFits(in: .horizontal) {
            subtitleRow(certification: true, size: true)
            subtitleRow(certification: true, size: deviceType != .phone)
            subtitleRow(certification: false, size: false)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    func subtitleRow(certification: Bool, size: Bool) -> some View {
        HStack(spacing: 6) {
            Text(movie.yearLabel)

            if let runtime = movie.runtimeLabel {
                Bullet()
                Text(runtime)
            }

            if certification {
                Bullet()
                Text(movie.certificationLabel)
            }

            if size, let size = movie.sizeLabel {
                Bullet()
                Text(size)
            }
        }
    }
}
