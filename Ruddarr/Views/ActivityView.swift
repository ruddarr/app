import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared
    @State var commands = Commands.shared

    @State var sort: QueueSort = .init()
    @State var items: [QueueItem] = []
    @State private var selectedItem: QueueItem?
    @State private var selectedCommand: InstanceCommandStatus?

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        NavigationStack {
            // swiftlint:disable:next closure_body_length
            Group {
                if settings.configuredInstances.isEmpty {
                    NoInstance()
                } else {
                    List {
                        if !commandItems.isEmpty {
                            Section {
                                ForEach(commandItems) { command in
                                    Button {
                                        selectedCommand = command
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
                                commandsSectionHeader
                            }
                        }

                        Section {
                            ForEach(items) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    QueueListItem(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                            #if os(macOS)
                                .padding(.vertical, 4)
                            #else
                                .listRowBackground(Color.card)
                            #endif
                        } header: {
                            if !items.isEmpty { queueSectionHeader }
                        }
                    }
                    #if os(iOS)
                        .background(.systemBackground)
                    #endif
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if items.isEmpty && commandItems.isEmpty {
                            queueEmpty
                        }
                    }
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarButtons
            }
            .onChange(of: sort.option, updateSortDirection)
            .onChange(of: sort, updateDisplayedItems)
            .onChange(of: queue.items, updateDisplayedItems)
            .onChange(of: queue.items, updateSelectedItem)
            .onChange(of: commands.items, updateSelectedCommand)
            .onAppear {
                queue.instances = settings.instances
                queue.performRefresh = true
                commands.instances = settings.instances
                commands.performRefresh = true
                updateDisplayedItems()
            }
            .onDisappear {
                queue.performRefresh = false
                commands.performRefresh = false
            }
            .task {
                await queue.fetchTasks()
            }
            .task {
                await commands.fetchAll()
            }
            .refreshable {
                Task { await queue.refreshDownloadClients() }
                Task { await commands.fetchAll() }
                await Task { await queue.fetchTasks() }.value
            }
            .sheet(item: $selectedItem) { item in
                QueueItemSheet(item: item)
                    .presentationDetents(dynamic: [
                        deviceType == .phone ? .fraction(0.7) : .large
                    ])
                    .presentationBackground(.sheetBackground)
                    .environmentObject(settings)
            }
            .sheet(item: $selectedCommand) { command in
                CommandSheet(command: command)
                    .presentationDetents(dynamic: [
                        deviceType == .phone ? .fraction(0.7) : .large
                    ])
                    .presentationBackground(.sheetBackground)
                    .environmentObject(settings)
            }
        }
    }

    var commandItems: [InstanceCommandStatus] {
        var cmds = commands.filteredItems(showAll: true)
        if sort.instance != .all {
            cmds = cmds.filter {
                $0.instanceId?.isEqual(to: sort.instance) == true
            }
        }
        return cmds
    }

    var commandsSectionHeader: some View {
        HStack(spacing: 6) {
            Text("\(commandItems.count) Running")

            if commands.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
    }

    var queueEmpty: some View {
        ContentUnavailableView(
            "Queues Empty",
            systemImage: "slash.circle",
            description: Text("All instance queues are empty.")
        )
    }

    var queueSectionHeader: some View {
        HStack(spacing: 6) {
            Text("\(items.count) Task")

            if queue.itemsWithIssues > 1 {
                Text("(\(queue.itemsWithIssues) Issue)")
            }

            if queue.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
    }

    func updateSelectedItem() {
        guard let taskId = selectedItem?.id else { return }
        guard let instanceId = selectedItem?.instanceId else { return }

        if let item = queue.items[instanceId]?.first(where: { $0.id == taskId }) {
            selectedItem = item
        } else {
            selectedItem = nil
        }
    }

    func updateSelectedCommand() {
        guard let commandId = selectedCommand?.commandId else { return }
        guard let instanceId = selectedCommand?.instanceId else { return }

        if let command = commands.items[instanceId]?.first(where: { $0.commandId == commandId }) {
            selectedCommand = command
        } else {
            selectedCommand = nil
        }
    }

    func updateDisplayedItems() {
        let grouped: [String: [QueueItem]] = Dictionary(
            grouping: queue.items.flatMap { $0.value },
            by: \.taskGroup
        ).mapValues { items -> [QueueItem] in
            guard var dummy = items.first else { return items }
            guard items.count > 1 else { return items }
            dummy.taskGroupCount = items.count
            return [dummy]
        }

        var items: [QueueItem] = grouped
            .flatMap { $0.value }
            .sorted(by: sort.option.isOrderedBefore)

        if sort.instance != .all {
            items = items.filter {
                $0.instanceId?.isEqual(to: sort.instance) == true
            }
        }

        if sort.type != .all {
            items = items.filter { $0.type.label == sort.type }
        }

        if sort.client != .all {
            items = items.filter { $0.downloadClient == sort.client }
        }

        if sort.issues {
            items = items.filter { $0.trackedDownloadStatus != .ok || $0.status == "warning" }
        }

        if !sort.isAscending {
            items = items.reversed()
        }

        withAnimation {
            self.items = items
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
