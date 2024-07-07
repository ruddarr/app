import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @State private var itemSheet: QueueItem?

    @EnvironmentObject var settings: AppSettings

    // output path
    // release title
    // TODO: Sonarr “Unknown” Download state (find out what's causing this)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button(action: {
                            itemSheet = item
                        }) {
                            QueueItemView(item: item)
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
                QueueItemSheet(item: item)
                    .presentationDetents([.medium])
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

    var sectionHeader: some View {
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

struct QueueItemView: View {
    var item: QueueItem

    @State private var time = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.titleLabel)
                .font(.headline.monospacedDigit())
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Text(item.statusLabel)

                if item.status != "completed" {
                    Bullet()
                    Text(item.progressLabel)
                        .monospacedDigit()

                    if let remaining = item.remainingLabel {
                        Bullet()
                        Text(remaining)
                            .monospacedDigit()
                            .id(time)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
