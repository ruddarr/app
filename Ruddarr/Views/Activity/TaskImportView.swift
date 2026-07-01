import SwiftUI
import Sentry

struct TaskImportView: View {
    var item: QueueItem
    var onRemove: () -> Void

    @State private var isLoading: Bool = true
    @State private var isWorking: Bool = false

    @State private var error: API.Error?
    @State private var files: [ImportableFile] = []
    @State private var selected = Set<ImportableFile.ID>()

    @Environment(AppSettings.self) private var settings

    var body: some View {
        List(files, selection: $selected) { file in
            FileImportRow(file: file, selected: binding(for: file.id))
        }
        #if os(macOS)
            .frame(minHeight: 200)
        #else
            .environment(\.editMode, .constant(EditMode.active))
        #endif
        .listStyle(.plain)
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
            } else if files.isEmpty {
                Text("No importable files found.")
            }
        }
        .sensoryAlert(
            isPresented: Binding(get: { self.error != nil }, set: { _ in }),
            error: error
        ) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
    }

    @ToolbarContentBuilder
    var toolbarImportButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task {
                    await importFiles()
                }
            } label: {
                if isWorking {
                    ButtonProgressView()
                } else {
                    Label("Import", systemImage: "arrow.down.to.line")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!isWorking)
            .tint(settings.theme.tint)
            .disabled(selectedFiles.isEmpty)
        }
    }

    var selectedFiles: [ImportableFile] {
        files.filter { selected.contains($0.id) }
    }

    private func loadFiles() async {
        error = nil
        isLoading = true

        guard let instanceId = item.instanceId else {
            leaveBreadcrumb(.fatal, category: "queue.import", message: "Missing instance identifier")
            return
        }

        guard let instance = settings.instanceById(instanceId) else {
            leaveBreadcrumb(.fatal, category: "queue.import", message: "Instance not found")
            return
        }

        guard let downloadId = item.downloadId else {
            leaveBreadcrumb(.fatal, category: "queue.import", message: "Missing download identifier")
            return
        }

        do {
            files = try await dependencies.api.fetchImportableFiles(downloadId, instance)
            selected = Set(files.acceptable().map(\.id))
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "queue.import", message: "Failed to fetch file", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isLoading = false
    }

    private func importFiles() async {
        error = nil
        isWorking = true

        guard let instanceId = item.instanceId else {
            leaveBreadcrumb(.fatal, category: "queue.import", message: "Missing instance identifier")
            return
        }

        guard let instance = settings.instanceById(instanceId) else {
            leaveBreadcrumb(.fatal, category: "queue.import", message: "Instance not found")
            return
        }

        do {
            _ = try await dependencies.api.command(.manualImport(selectedFiles), instance)

            dependencies.toast.show(.importQueued)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "queue.import", message: "Manual import failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false

        if error == nil {
            onRemove()
        }
    }

    private func binding(for id: ImportableFile.ID) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                selected.contains(id)
            },
            set: {
                if $0 {
                    selected.insert(id)
                } else {
                    selected.remove(id)
                }
            }
        )
    }
}

private struct FileImportRow: View {
    var file: ImportableFile
    @Binding var selected: Bool

    var body: some View {
        HStack {
            #if os(macOS)
                Toggle(isOn: $selected) { }
                    .padding(.trailing, 8)
            #endif

            VStack(alignment: .leading) {
                Text(file.relativePath ?? file.name ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(file.qualityLabel)

                    Bullet()
                    Text(file.sizeLabel)

                    Bullet()
                    Text(file.languageLabel)
                }
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .font(.subheadline)

                VStack(alignment: .leading) {
                    ForEach(file.reasons, id: \.self) { reason in
                        Text(reason)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    let settings = AppSettings()
    let instanceId = settings.radarrInstance?.id

    let items: QueueItems = PreviewData.loadObject(name: "movie-queue")

    let item = {
        var record = items.records[0]
        record.instanceId = instanceId
        return record
    }()

    NavigationStack {
        TaskImportView(item: item, onRemove: {})
    }.withAppState()
}

#Preview("No Files") {
    let settings = AppSettings()
    let instanceId = settings.sonarrInstance?.id

    let items: QueueItems = PreviewData.loadObject(name: "series-queue")

    let item = {
        var record = items.records.first!
        record.instanceId = instanceId
        return record
    }()

    NavigationStack {
        TaskImportView(item: item, onRemove: {})
    }.withAppState()
}
