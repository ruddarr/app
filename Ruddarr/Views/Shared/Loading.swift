import Combine
import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

/// Renders the symbol for a tracked queue status (see `View.tracksQueueStatus`).
struct QueueStatusIcon: View {
    var status: QueueItemStatus
    var color: Color = .secondary

    var body: some View {
        switch status {
        case .downloading: Downloading(color: color)
        case .importBlocked: ImportBlocked(color: color)
        }
    }
}

struct Downloading: View {
    var color: Color = .secondary
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Image(systemName: "arrow.down.circle")
            .symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 0.5)))
            .symbolRenderingMode(.palette)
            .foregroundStyle(settings.theme.tint, color)
    }
}

struct ImportBlocked: View {
    var color: Color = .secondary
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Image(systemName: "exclamationmark.triangle")
            .symbolRenderingMode(.palette)
            .foregroundStyle(settings.theme.tint, color)
    }
}

#Preview {
    Loading()
}

#Preview("Queue Status") {
    HStack {
        QueueStatusIcon(status: .downloading)
        QueueStatusIcon(status: .downloading, color: .lightGray)
        QueueStatusIcon(status: .importBlocked)
        QueueStatusIcon(status: .importBlocked, color: .lightGray)
    }
    .withAppState()
}
