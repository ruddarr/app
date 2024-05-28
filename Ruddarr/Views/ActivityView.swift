import SwiftUI

struct ActivityView: View {
    @State var queue = Queue.shared

    @EnvironmentObject var settings: AppSettings

    // TODO: sheet with details

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        QueueItemView(item: item)
                    }
                    .listRowBackground(Color.secondarySystemBackground)
                } header: {
                    if !items.isEmpty {
                        Text("\(items.count) Tasks")
                    }
                }
            }
            .background(.systemBackground)
            .scrollContentBackground(.hidden)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                reloadButton
            }
            .onAppear {
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

    @State private var time = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()

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

                if let remaining = item.remainingLabel {
                    Bullet()
                    Text(remaining).id(time)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
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
