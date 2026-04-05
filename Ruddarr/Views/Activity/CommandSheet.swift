import SwiftUI

struct CommandSheet: View {
    var command: InstanceCommandStatus

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                details
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command.subject ?? command.commandName ?? command.name)
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Image(systemName: command.state.systemImage)
                Text(command.state.label)
            }
            .font(.subheadline)
            .foregroundStyle(stateTint)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(String(localized: "Instance"), instanceLabel)
            row(String(localized: "Command"), command.commandName ?? command.name)
            if let result = command.result { row(String(localized: "Result"), result) }
            if let message = command.message { row(String(localized: "Message"), message) }
            row(String(localized: "Queued"), command.queued.formatted(date: .omitted, time: .standard))
            if let started = command.started {
                row(String(localized: "Started"), started.formatted(date: .omitted, time: .standard))
            }
            if let ended = command.ended {
                row(String(localized: "Ended"), ended.formatted(date: .omitted, time: .standard))
            }
            if let duration = durationLabel {
                row(String(localized: "Duration"), duration)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var instanceLabel: String {
        guard let id = command.instanceId,
              let instance = settings.instances.first(where: { $0.id == id })
        else { return "—" }
        return instance.label
    }

    private var durationLabel: String? {
        guard let started = command.started, let ended = command.ended else { return nil }
        let secs = Int(ended.timeIntervalSince(started))
        if secs < 60 { return "\(secs)s" }
        return "\(secs / 60)m \(secs % 60)s"
    }

    private var stateTint: Color {
        switch command.state {
        case .completed: .green
        case .failed, .aborted, .orphaned: .red
        case .cancelled: .secondary
        case .queued, .started: .accentColor
        case .unknown: .secondary
        }
    }
}
