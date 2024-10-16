import SwiftUI

struct QueueTaskRemovalSheet: View {
    var item: QueueItem
    var onRemove: () -> Void

    @State private var remove: Bool = false
    @State private var block: Bool = false
    @State private var search: Bool = false

    @State private var error: API.Error?
    @State private var isWorking: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Remove from Client", isOn: $remove)
                } footer: {
                    Text("Whether to ignore the download, or remove it and its file(s) from the download client.")
                }

                Section {
                    Toggle("Blocklist Release", isOn: $block)

                    if block {
                        Toggle("Search for Replacement", isOn: $search)
                    }
                } footer: {
                    Text("Blocks this release from being redownloaded via Automatic Search or RSS.")
                }
            }
            .padding(.top, -20)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                toolbarCloseButton
                toolbarRemoveButton
            }
            .alert(
                isPresented: Binding(
                    get: { self.error != nil },
                    set: { _ in }
                ),
                error: error
            ) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarCloseButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarRemoveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Remove") {
                    Task {
                        await deleteTask()
                        await Queue.shared.fetchTasks()
                        dismiss()
                        onRemove()
                    }
                }
            }
        }
    }

    func deleteTask() async {
        error = nil
        isWorking = true

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
}
