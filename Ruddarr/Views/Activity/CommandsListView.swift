import SwiftUI

struct CommandsListView: View {
    @State var commands = Commands.shared
    @State private var selected: InstanceCommandStatus?
    @State private var showAll: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        Group {
            if settings.configuredInstances.isEmpty {
                NoInstance()
            } else {
                List {
                    Section {
                        ForEach(filteredItems) { command in
                            Button {
                                selected = command
                            } label: {
                                CommandListItem(command: command)
                            }
                            .buttonStyle(.plain)
                        }
                        #if os(macOS)
                            .padding(.vertical, 4)
                        #else
                            .listRowBackground(Color.card)
                        #endif
                    } header: {
                        sectionHeader
                    }
                }
                #if os(iOS)
                    .background(.systemBackground)
                #endif
                .scrollContentBackground(.hidden)
                .overlay {
                    if filteredItems.isEmpty {
                        empty
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showAll) {
                    Label(
                        "Show All Tasks",
                        systemImage: showAll ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                    )
                }
                .toggleStyle(.button)
                .tint(.primary)
            }
        }
        .onAppear {
            commands.instances = settings.instances
            commands.performRefresh = true
        }
        .onDisappear {
            commands.performRefresh = false
        }
        .task {
            await commands.fetchAll()
        }
        .refreshable {
            await Task { await commands.fetchAll() }.value
        }
        .sheet(item: $selected) { command in
            CommandSheet(command: command)
                .presentationDetents(dynamic: [
                    deviceType == .phone ? .fraction(0.7) : .large
                ])
                .presentationBackground(.sheetBackground)
                .environmentObject(settings)
        }
        .onChange(of: commands.items) { updateSelected() }
    }

    private func updateSelected() {
        guard let current = selected else { return }
        if let fresh = commands.items[current.instanceId ?? UUID()]?.first(where: { $0.id == current.id }) {
            selected = fresh
        }
    }

    private var filteredItems: [InstanceCommandStatus] {
        commands.filteredItems(showAll: showAll)
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Text("\(filteredItems.count) Task")

            if commands.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView(
            "No Recent Tasks",
            systemImage: "checklist",
            description: Text("Automatic searches and other commands will appear here.")
        )
    }
}
