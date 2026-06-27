import Combine
import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

/// Renders the symbol for a queue status (see `View.tracksQueueStatus`).
/// The symbol and whether it pulses are driven by `QueueItemStatus`, so any
/// state — including ones without a bespoke treatment — resolves to a symbol.
struct QueueStatusIcon: View {
    var status: QueueItemStatus
    var color: Color = .secondary

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let icon = Image(systemName: status.systemImage)
            .symbolRenderingMode(.palette)
            .foregroundStyle(settings.theme.tint, color)

        if status.pulses {
            icon.symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 0.5)))
        } else {
            icon
        }
    }
}

/// Standalone downloading indicator for item-level views not driven by `Queue.statuses`.
struct Downloading: View {
    var color: Color = .secondary

    var body: some View {
        QueueStatusIcon(status: .downloading, color: color)
    }
}

#Preview {
    Loading()
}

#Preview("Queue Status") {
    let statuses: [QueueItemStatus] = [
        .downloading, .importing, .queued, .importPending,
        .paused, .warning, .importBlocked, .failed, .unknown,
    ]

    VStack(spacing: 16) {
        ForEach(statuses, id: \.self) { status in
            HStack(spacing: 16) {
                QueueStatusIcon(status: status)
                QueueStatusIcon(status: status, color: .lightGray)
            }
        }
    }
    .imageScale(.large)
    .withAppState()
}
