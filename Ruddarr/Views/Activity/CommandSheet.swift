import SwiftUI

struct CommandSheet: View {
    var command: InstanceCommandStatus

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Divider()
                    details
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .hideIconOnMac()
                    .tint(.primary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command.displayTitle)
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
            row("Instance", instanceLabel)
            row("Command", command.commandName ?? command.name)
            if let result = command.result { row("Result", result) }
            if let message = command.message { row("Message", message) }
            row("Queued", command.queued.formatted(date: .abbreviated, time: .shortened))
            if let started = command.started {
                row("Started", started.formatted(date: .abbreviated, time: .shortened))
            }
            if let ended = command.ended {
                row("Ended", ended.formatted(date: .abbreviated, time: .shortened))
            }
            if let duration = durationLabel {
                row("Duration", duration)
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
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
        return formatDuration(ended.timeIntervalSince(started))
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
