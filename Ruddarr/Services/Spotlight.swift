import zlib
import Nuke
import CoreSpotlight

class Spotlight {
    private let instance: Instance

    static var instances: [Instance.ID: Spotlight] = [:]

    init(_ instance: Instance) {
        self.instance = instance
    }

    var checksumKey: String {
        "spotlight:\(instance.id)"
    }

    static func of(_ instance: Instance) -> Spotlight {
        if let singleton = instances[instance.id] {
            return singleton
        }

        instances[instance.id] = Spotlight(instance)

        return instances[instance.id]!
    }

    func indexMovies(_ movies: [Movie]) {
        guard instance.mode == .normal else { return }

        Task.detached(priority: .background) {
            let checksum = self.calculateChecksum(
                movies.map { $0.spotlightHash }.joined(separator: "+")
            )

            if self.isIndexed(checksum) {
                return
            }

            var entities: [Movie] = movies
            let indexName = self.instance.id.uuidString

            leaveBreadcrumb(.info, category: "spotlight", message: "Indexing movies", data: ["count": entities.count, "instance": indexName])

            for entity in entities.indices {
                entities[entity].remotePosterCached = await Images.thumbnail(
                    entities[entity].remotePoster
                )
            }

            do {
                let chunk = 1_000
                let index = CSSearchableIndex(name: indexName)
                try await index.deleteAllSearchableItems()

                for start in stride(from: 0, to: entities.count, by: chunk) {
                    let end = min(start + chunk, entities.count)

                    try await index.indexSearchableItems(
                        entities[start..<end].map { $0.searchableItem }
                    )
                }

                dependencies.store.set(checksum, forKey: self.checksumKey)

                leaveBreadcrumb(.info, category: "spotlight", message: "Indexed movies", data: ["count": entities.count, "instance": indexName])
            } catch {
                leaveBreadcrumb(.error, category: "spotlight", message: "Failed to index movies", data: ["error": error])
            }
        }
    }

    func indexSeries(_ series: [Series]) {
        guard instance.mode == .normal else { return }

        Task.detached(priority: .background) {
            let checksum = self.calculateChecksum(
                series.map { $0.spotlightHash }.joined(separator: "+")
            )

            if self.isIndexed(checksum) {
                return
            }

            var entities: [Series] = series
            let indexName = self.instance.id.uuidString

            leaveBreadcrumb(.info, category: "spotlight", message: "Indexing series", data: ["count": entities.count, "instance": indexName])

            for entity in entities.indices {
                entities[entity].remotePosterCached = await Images.thumbnail(
                    entities[entity].remotePoster
                )
            }

            do {
                let chunk = 1_000
                let index = CSSearchableIndex(name: indexName)
                try await index.deleteAllSearchableItems()

                for start in stride(from: 0, to: entities.count, by: chunk) {
                    let end = min(start + chunk, entities.count)

                    try await index.indexSearchableItems(
                        entities[start..<end].map { $0.searchableItem }
                    )
                }

                dependencies.store.set(checksum, forKey: self.checksumKey)

                leaveBreadcrumb(.info, category: "spotlight", message: "Indexed movies", data: ["count": entities.count, "instance": indexName])
            } catch {
                leaveBreadcrumb(.error, category: "spotlight", message: "Failed to index movies", data: ["error": error])
            }
        }
    }

    func deleteInstanceIndex() async {
        dependencies.store.removeObject(forKey: checksumKey)

        let index = CSSearchableIndex(name: instance.id.uuidString)
        try? await index.deleteAllSearchableItems()
    }

    func calculateChecksum(_ string: String) -> String {
        let data = string.data(using: .utf8) ?? Data()

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
