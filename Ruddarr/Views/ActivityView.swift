import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @State var sort: QueueSort = .init()
    @State var items: [QueueItem] = []
    @State private var itemSheet: QueueItem?

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
                                    itemSheet = item
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
            .onAppear {
                queue.instances = settings.instances
                queue.performRefresh = true
            }
            .onDisappear {
                queue.performRefresh = false
            }
            .task {
                await queue.fetchTasks()
                updateDisplayedItems()
            }
            .refreshable {
                Task { await queue.refreshDownloadClients() }
                await Task { await queue.fetchTasks() }.value
            }
            .sheet(item: $itemSheet) { item in
                QueueItemSheet(item: item)
                    .presentationDetents([deviceType == .phone ? .medium : .large])
                    .environmentObject(settings)
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
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
