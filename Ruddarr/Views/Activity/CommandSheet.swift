import SwiftUI

struct CommandSheet: View {
    var command: InstanceCommandStatus

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header

                    details
                        .padding(.top)
                }
                .scenePadding(.horizontal)
                #if os(macOS)
                    .padding(.top, 24)
                #else
                    .offset(y: -45)
                #endif
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

    @ViewBuilder
    var header: some View {
        HStack(spacing: 6) {
            Image(systemName: command.state.systemImage)
            Text(command.state.label)
        }
        .foregroundStyle(command.state.tint)
        .font(.caption)
        .fontWeight(.semibold)
        .textCase(.uppercase)
        .tracking(1.1)

        Text(command.displayTitle)
            .font(.title3.bold())
            .kerning(-0.5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, 56)
    }

    var details: some View {
        Section {
            VStack(spacing: 6) {
                row("Instance", instanceLabel)

                Divider()
                row("Command", command.commandName ?? command.name)

                if let result = command.result {
                    Divider()
                    row("Result", result)
                }

                if let message = command.message {
                    Divider()
                    row("Message", message)
                }

                Divider()
                row("Queued", command.queued.formatted(date: .long, time: .shortened))

                if let started = command.started {
                    Divider()
                    row("Started", started.formatted(date: .long, time: .shortened))
                }

                if let ended = command.ended {
                    Divider()
                    row("Ended", ended.formatted(date: .long, time: .shortened))
                }

                if let started = command.started, let ended = command.ended {
                    Divider()
                    row("Duration", formatDuration(ended.timeIntervalSince(started)))
                }
            }
            .padding(.bottom)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        row(label, Text(value).foregroundStyle(.primary))
    }

    func row<V: View>(_ label: LocalizedStringKey, _ value: V) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
            Spacer()

            value
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
        .padding(.vertical, 4)
    }

    var instanceLabel: String {
        guard let id = command.instanceId,
              let instance = settings.instances.first(where: { $0.id == id })
        else { return "—" }
        return instance.label
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
