import SwiftUI

struct QueueListItem: View {
    var item: QueueItem

    @State private var time = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.titleLabel)
                .font(.headline.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(item.statusLabel)

                if item.status != "completed" {
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

                if item.trackedDownloadStatus != .ok {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.small)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onReceive(timer) { _ in
            if item.trackedDownloadState == .downloading {
                time = Date()
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
