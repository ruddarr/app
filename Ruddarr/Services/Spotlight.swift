import CoreSpotlight
import zlib

actor Spotlight {
    var instanceId: Instance.ID

    init(_ instanceId: Instance.ID) {
        self.instanceId = instanceId
    }

    var checksumKey: String {
        "spotlight:\(instanceId)"
    }

    func index<M: Media>(_ entities: [M], delay: Duration? = nil) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        Task(priority: .background) {
            let checksum = self.calculateChecksum(
                entities.map { $0.searchableHash }.joined(separator: "+")
            )

            if self.isIndexed(checksum) {
                return
            }

            if let sleepDelay = delay {
                try await Task.sleep(for: sleepDelay)
            }

            let typeName = String(describing: M.self)
            let indexName = instanceId.uuidString

            leaveBreadcrumb(.info, category: "spotlight", message: "Indexing [\(typeName)]", data: ["count": entities.count, "instance": indexName])

            let images = await fetchImages(entities)

            do {
                let chunk = 1_000
                let index = CSSearchableIndex(name: indexName)
                try await index.deleteSearchableItems(withDomainIdentifiers: [indexName])

                for start in stride(from: 0, to: entities.count, by: chunk) {
                    let end = min(start + chunk, entities.count)

                    try await index.indexSearchableItems(
                        entities[start..<end].map {
                            $0.searchableItem(poster: images[$0.id] ?? nil)
                        }
                    )
                }

                dependencies.store.set(checksum, forKey: self.checksumKey)

                leaveBreadcrumb(.info, category: "spotlight", message: "Indexed [\(typeName)]", data: ["count": entities.count, "instance": indexName])
            } catch {
                leaveBreadcrumb(.error, category: "spotlight", message: "Failed to index [\(typeName)]", data: ["error": error])
            }
        }
    }

    func fetchImages<M: Media>(_ entities: [M]) async -> [M.ID: URL?] {
        await withTaskGroup(of: (M.ID, URL?).self, returning: [M.ID: URL?].self) { taskGroup in
            for entry in entities {
                taskGroup.addTask(priority: .background) {
                    await (entry.id, Images.thumbnail(entry.remotePoster, .veryLow))
                }
            }

            var images = [M.ID: URL?]()

            for await (id, url) in taskGroup {
                images[id] = url
            }

            return images
        }
    }

    func deleteInstanceIndex() async {
        dependencies.store.removeObject(forKey: checksumKey)

        do {
            let index = CSSearchableIndex(name: instanceId.uuidString)
            try await index.deleteSearchableItems(withDomainIdentifiers: [instanceId.uuidString])
        } catch {
            leaveBreadcrumb(.error, category: "spotlight", message: "Failed to delete index", data: ["error": error])
        }
    }

    func calculateChecksum(_ string: String) -> String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let data = "\(build):\(string)".data(using: .utf8) ?? Data()

        let checksum = data.withUnsafeBytes {
            crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))
        }

        return String(format: "%08x", checksum)
    }

    func isIndexed(_ hash: String) -> Bool {
        let storedHash = dependencies.store.string(forKey: checksumKey)

        return hash == storedHash
    }
}
