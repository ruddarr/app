import SwiftUI

struct QueueListItem: View {
    var item: QueueItem

    @State private var time = Date()
    @EnvironmentObject var settings: AppSettings

    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onReceive(timer) { _ in
                if item.trackedDownloadState == .downloading {
                    withAnimation {
                        time = Date()
                    }
                }
            }
    }

    @ViewBuilder
    var content: some View {
        if settings.richActivityDisplay {
            richContent
                .padding(8)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 14))
        } else {
            compactContent
        }
    }

    var richContent: some View {
        HStack(alignment: .center, spacing: 10) {
            QueuePoster(url: item.remotePoster, title: item.posterPlaceholder)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.titleLabel)
                    .font(.headline.monospacedDigit())
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.trackedDownloadState == .downloading {
                    downloadProgress
                } else {
                    status
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var compactContent: some View {
        VStack(alignment: .leading) {
            Text(item.titleLabel)
                .font(.headline.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(item.statusLabel)

                if item.trackedDownloadState == .downloading {
                    Bullet()
                    Text(item.progressLabel)
                        .monospacedDigit()

                    if let remaining = item.remainingLabel {
                        Bullet()
                        Text(remaining)
                            .monospacedDigit()
                            .id(time)
                    }
                }

                if item.hasIssue {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.small)
                        .foregroundStyle(.tint)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    var status: some View {
        HStack(spacing: 6) {
            Text(item.statusLabel)

            if item.hasIssue {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    var downloadProgress: some View {
        ProgressView(value: progressValue, total: progressTotal) {
            HStack(spacing: 6) {
                Text(item.progressLabel)
                    .monospacedDigit()

                Spacer()

                Text(item.remainingLabel ?? "")
                    .monospacedDigit()
                    .id(time)

                if item.hasIssue {
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.small)
                        .foregroundStyle(.tint)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    var progressValue: Float {
        max(0, item.size - item.sizeleft)
    }

    var progressTotal: Float {
        max(item.size, 1)
    }
}

private struct QueuePoster: View {
    var url: String?
    var title: String?

    var body: some View {
        CachedAsyncImage(.poster, url, placeholder: title)
            .aspectRatio(CGSize(width: 150, height: 225), contentMode: .fill)
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
