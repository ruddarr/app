import SwiftUI

struct TaskImportView: View {
    var item: QueueItem
    var onRemove: () -> Void

    @State private var isLoading: Bool = true
    @State private var isWorking: Bool = false

    @State private var items: [ImportItem] = []

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            // 3. Display files or message...
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            toolbarImportButton
        }
        .task {
            await loadFiles()
        }
        .overlay {
            if isLoading {
                Loading()
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarImportButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Import") {
                    Task {
//                        await deleteTask()
//                        await Queue.shared.fetchTasks()
//                        onRemove()
                    }
                }
            }
        }
    }

    func loadFiles() async {
        guard let instanceId = item.instanceId else {
            leaveBreadcrumb(.fatal, category: "queue", message: "Missing instance identifier")
            return
        }

        guard let instance = settings.instanceById(instanceId) else {
            leaveBreadcrumb(.fatal, category: "queue", message: "Instance not found")
            return
        }

        do {
            _ = try await dependencies.api.deleteQueueTask(
                item.id, remove, block, search, instance
            )
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "queue", message: "Task deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false
    }

    func deleteTask() async {
        //
    }
}

#Preview {
    let items: QueueItems = PreviewData.loadObject(name: "movie-queue")
    let item = items.records[2]

    NavigationStack {
        QueueItemSheet(item: item)
    }.withAppState()
}
