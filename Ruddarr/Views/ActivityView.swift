import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @State private var itemSheet: QueueItem?

    @EnvironmentObject var settings: AppSettings

    // TODO: Sonarr “Unknown” Download state (find out what's causing this)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button(action: { itemSheet = item}) {
                            QueueItemView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.secondarySystemBackground)
                } header: {
                    if !items.isEmpty {
                        HStack(spacing: 6) {
                            Text("\(items.count) Tasks")

                            if queue.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.secondary)
                            }
                        }
                    }
                }
            }
            .background(.systemBackground)
            .scrollContentBackground(.hidden)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                // TODO: show instance picker (center)
                // TODO: sort by date added, title
            }
            .onAppear {
                queue.instances = settings.instances

                Task { await queue.fetch() }
            }
            .refreshable {
                await Task { await queue.fetch() }.value
            }
            .sheet(item: $itemSheet) { item in
                QueueItemSheet(item: item).presentationDetents([.medium])
            }
            .overlay {
                if items.isEmpty {
                    queueEmpty
                }
            }
        }
    }

    var items: [QueueItem] {
        queue.items
            .flatMap { $0.value }
            .sorted { $0.added ?? Date.distantPast > $1.added ?? Date.distantPast }
    }

    var queueEmpty: some View {
        ContentUnavailableView(
            "No Tasks",
            systemImage: "slash.circle",
            description: Text("All instance queues are empty.")
        )
    }
}

struct QueueItemView: View {
    var item: QueueItem

    @State private var time = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.itemTitle ?? "Unknown")
                .font(.headline.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(item.statusLabel)
                Bullet()
                Text(item.progressLabel)

                if let remaining = item.remainingLabel {
                    Bullet()
                    Text(remaining).id(time)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
