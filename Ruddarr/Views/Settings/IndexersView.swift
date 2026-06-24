import SwiftUI

struct IndexersView: View {
    let instance: Instance
    @State var prowlarr: ProwlarrInstance

    init(instance: Instance) {
        self.instance = instance
        self._prowlarr = State(wrappedValue: ProwlarrInstance(instance))
    }

    var body: some View {
        List {
            ForEach($prowlarr.indexers) { $indexer in
                NavigationLink(value: indexer) {
                    IndexerRow(indexer: $indexer, prowlarr: prowlarr)
                }
            }
        }
        .navigationTitle("Indexers")
        .safeNavigationBarTitleDisplayMode(.inline)
        .task { await prowlarr.fetchIndexers() }
        .refreshable { await refresh() }
        .overlay {
            if prowlarr.isLoading && prowlarr.indexers.isEmpty {
                ProgressView()
            } else if !prowlarr.isLoading && prowlarr.indexers.isEmpty {
                if let error = prowlarr.error {
                    ContentUnavailableView {
                        Label("Indexers could not be loaded", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.recoverySuggestionFallback)
                    } actions: {
                        Button("Retry") {
                            Task { await prowlarr.fetchIndexers() }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Indexers",
                        systemImage: "magnifyingglass",
                        description: Text("Add indexers in the Prowlarr web interface.")
                    )
                }
            }
        }
        .navigationDestination(for: Indexer.self) { indexer in
            IndexerDetailView(indexer: indexer, instance: instance)
        }
    }

    func refresh() async {
        await prowlarr.fetchIndexers()
        if let error = prowlarr.error, !prowlarr.indexers.isEmpty {
            dependencies.toast.show(.error(error.recoverySuggestionFallback))
        }
    }
}

struct IndexerRow: View {
    @Binding var indexer: Indexer
    let prowlarr: ProwlarrInstance

    @State private var isCommitting = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(indexer.name)
                HStack(spacing: 6) {
                    Text(indexer.protocol.label)
                    Text(verbatim: "•")
                    Text(indexer.privacy.label)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(isOn: Binding(
                get: { indexer.enable },
                set: { newValue in
                    indexer.enable = newValue
                    Task { await commitEnabled(newValue) }
                }
            )) { }
            .labelsHidden()
            .disabled(isCommitting)
        }
    }

    func commitEnabled(_ newValue: Bool) async {
        isCommitting = true
        defer { isCommitting = false }

        guard await prowlarr.setEnabled(indexer.id, newValue) else {
            indexer.enable = !newValue
            dependencies.toast.show(.error(
                prowlarr.error?.recoverySuggestionFallback ?? String(localized: "Try again later.")))
            return
        }
        dependencies.toast.show(newValue ? .indexerEnabled : .indexerDisabled)
    }
}
