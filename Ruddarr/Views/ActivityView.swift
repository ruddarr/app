import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @EnvironmentObject var settings: AppSettings

    // TODO: sheet with details
    // TODO: reload button
    // TODO: already reload when coming into view!!!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        QueueItemView(item: item)
                    }
                    .listRowBackground(Color.secondarySystemBackground)
                }
                // header: { Text("\(items.count) Tasks") }
            }
            .background(.systemBackground)
            .scrollContentBackground(.hidden)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                reloadButton
            }
            .onAppear {
                print("on appear")
                queue.instances = settings.instances

                Task {
                    await queue.fetch()
                }
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
            "Queue Empty",
            systemImage: "slash.circle",
            description: Text("All instance queues are empty.")
        )
    }

    var reloadButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                Task { await queue.fetch() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .scaleEffect(0.85)
                    .opacity(queue.isLoading ? 0 : 1)
                    .overlay {
                        if queue.isLoading {
                            ProgressView().tint(.secondary)
                        }
                    }
            }
        }
    }
}

struct QueueItemView: View {
    var item: QueueItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(item.title ?? "Unknown")
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(item.statusLabel)
                Bullet()
                Text(item.progressLabel)

                // TODO: 1h 14min

                if item.trackedDownloadState == .downloading {
                    Bullet()
                    Text(item.timeleft ?? "???")
                    // TODO: estimatedCompletionTime
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
