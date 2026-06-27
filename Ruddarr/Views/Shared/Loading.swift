import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

struct QueueStatusIcon: View {
    var status: QueueItemStatus
    var color: Color = .secondary

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let icon = status.image
            .symbolRenderingMode(.palette)
            .foregroundStyle(settings.theme.tint, color)
            .accessibilityLabel(status.label)

        if status.pulses {
            icon.symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 0.2)))
        } else {
            icon
        }
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
