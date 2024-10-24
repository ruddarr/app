import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared
    @State var history: History = .init()

    @State var sort: QueueSort = .init()
    @State var items: [QueueItem] = []
    @State private var itemSheet: QueueItem?
    @State private var eventSheet: MediaHistoryEvent?
    @State private var historyPage: Int = 0

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        NavigationStack {
            ScrollView {
                if settings.configuredInstances.isEmpty {
                    NoInstance()
                } else {
                    Group {
                        activity
                        events
                    }
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarButtons
            }
            .refreshable {
                Task { await queue.refreshDownloadClients() }
                await Task { await queue.fetchTasks() }.value
            }
            .padding(.all)
        }
    }
    
    var activity: some View {
        Section {
            List {
                ForEach(items) { item in
                    Button {
                        itemSheet = item
                    } label: {
                        QueueListItem(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.secondarySystemBackground)
            }
        } header: {
            if !items.isEmpty { sectionHeader }
        }
        .background(.systemBackground)
        .scrollContentBackground(.hidden)
        .overlay {
            if items.isEmpty {
                queueEmpty
            }
        }
        .onChange(of: sort.option, updateSortDirection)
        .onChange(of: sort, updateDisplayedItems)
        .onChange(of: queue.items, updateDisplayedItems)
        .onAppear {
            queue.instances = settings.instances
            queue.performRefresh = true
        }
        .onDisappear {
            queue.performRefresh = false
        }
        .task {
            await queue.fetchTasks()
        }
        .sheet(item: $itemSheet) { item in
            QueueItemSheet(item: item)
                .presentationDetents([deviceType == .phone ? .medium : .large])
                .environmentObject(settings)
        }
    }

    var events: some View {
        Section {
            if history.isLoading {
                ProgressView().tint(.secondary)
            } else if history.error != nil {
                Text("An error occurred.")
            } else {
                Group {
                    ForEach(history.items) { event in
                        MediaHistoryItem(event: event)
                            .padding(.bottom, 4)
                            .onTapGesture { eventSheet = event }
                    }
                    if history.hasMore.values.contains(true) {
                        Button("Load More") {
                            historyPage += 1
                            Task { await history.fetch(historyPage) }
                        }
                    }
                }
            }
        } header: {
            Text("History")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            history.instances = settings.instances
            historyPage = 1
        }
        .task {
            await history.fetch(historyPage)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
        }
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
