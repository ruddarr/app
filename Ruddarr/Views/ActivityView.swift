import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @State var sort: QueueSort = .init()
    @State var items: [QueueItem] = []
    @State private var selectedItem: QueueItem?

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        // swiftlint:disable closure_body_length
        NavigationStack {
            Group {
                if settings.configuredInstances.isEmpty {
                    NoInstance()
                } else {
                    List {
                        Section {
                            ForEach(items) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    QueueListItem(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Color.secondarySystemBackground)
                        } header: {
                            if !items.isEmpty { sectionHeader }
                        }
                    }
                    .background(.systemBackground)
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if items.isEmpty {
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
            .onAppear {
                queue.instances = settings.instances
                queue.performRefresh = true
                updateDisplayedItems()
            }
            .onDisappear {
                queue.performRefresh = false
            }
            .task {
                await queue.fetchTasks()
            }
            .refreshable {
                Task { await queue.refreshDownloadClients() }
                await Task { await queue.fetchTasks() }.value
            }
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    QueueItemSheet(item: item)
                        .presentationDetents([
                            deviceType == .phone ? .fraction(0.7) : .large
                        ])
                        .environmentObject(settings)
                }
            }
        }
        // swiftlint:enable closure_body_length
    }

    var queueEmpty: some View {
        ContentUnavailableView(
            "No Tasks",
            systemImage: "slash.circle",
            description: Text("All instance queues are empty.")
        )
    }

    var sectionHeader: some View {
        HStack(spacing: 6) {
            Text("\(items.count) Tasks")

            if queue.badgeCount > 1 {
                Text("(\(queue.badgeCount) Issues)")
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
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
