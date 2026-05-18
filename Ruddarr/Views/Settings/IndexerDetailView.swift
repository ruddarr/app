import SwiftUI

struct IndexerDetailView: View {
    let indexer: Indexer
    let instance: Instance

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: indexer.name)
                if let def = indexer.definitionName, def != indexer.name {
                    LabeledContent("Type", value: def)
                }
                LabeledContent("Protocol", value: indexer.protocol.label)
                LabeledContent("Privacy", value: indexer.privacy.label)
                LabeledContent("Priority", value: String(indexer.priority))
                if let lang = indexer.language {
                    LabeledContent("Language", value: lang)
                }
                if let added = indexer.added {
                    LabeledContent("Added", value: added.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if let desc = indexer.description, !desc.isEmpty {
                Section("Description") {
                    Text(desc)
                }
            }

            if !indexer.tags.isEmpty {
                Section("Tags") {
                    ForEach(indexer.tags, id: \.self) { tagId in
                        if let tag = instance.tags.first(where: { $0.id == tagId }) {
                            Text(tag.label)
                        }
                    }
                }
            }

            if let caps = indexer.capabilities,
               let cats = caps.categories,
               !cats.isEmpty {
                Section("Categories") {
                    ForEach(cats) { cat in
                        Text(cat.name)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .textCase(nil)
        .navigationTitle(indexer.name)
        .safeNavigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        IndexerDetailView(
            indexer: Indexer(
                id: 1,
                name: "1337x",
                definitionName: "1337x",
                description: "Public torrent tracker.",
                enable: true,
                protocol: .torrent,
                privacy: .public,
                priority: 25,
                language: "en-US",
                added: Date(),
                appProfileId: 1,
                tags: [],
                capabilities: nil
            ),
            instance: .prowlarrDummy
        )
    }
}
