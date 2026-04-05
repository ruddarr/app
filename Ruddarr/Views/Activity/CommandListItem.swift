import SwiftUI

struct CommandListItem: View {
    var command: InstanceCommandStatus

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            Text(titleLabel)
                .font(.headline.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Image(systemName: command.state.systemImage)
                    .imageScale(.small)
                Text(command.state.label)

                if let subline {
                    Bullet()
                    Text(subline)
                        .monospacedDigit()
                        .id(now)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onReceive(timer) { _ in
            if command.state == .started || command.state == .queued {
                withAnimation { now = Date() }
            }
        }
    }

    private var titleLabel: String {
        command.subject ?? command.commandName ?? command.name
    }

    private var subline: String? {
        switch command.state {
        case .started, .queued:
            let elapsed = now.timeIntervalSince(command.started ?? command.queued)
            return formatElapsed(elapsed)
        case .completed, .failed, .aborted, .cancelled, .orphaned, .unknown:
            guard let ended = command.ended else { return nil }
            return ended.formatted(.relative(presentation: .named))
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let r = s % 60
        return "\(m)m \(r)s"
    }
}
