import Foundation

class Migrations {
    static let key = "schemaVersion"
    static let appGroupKey = "migratedToAppGroup"

    static func run() {
        migrateToAppGroup()

        let current = currentBuild()
        let stored = storedSchema()

        if stored != current {
            migrateFrom(stored ?? 0, to: current)
            save(current)
        }
    }

    /// Copy settings written to standard `UserDefaults` (pre-App-Group builds)
    /// into the shared App Group suite, once. Instances stored via iCloud
    /// migrate on their own (same key name in the key-value store).
    private static func migrateToAppGroup() {
        let group = dependencies.store

        guard !group.bool(forKey: appGroupKey) else { return }
        guard group != UserDefaults.standard else { return }

        if let bundleId = Bundle.main.bundleIdentifier,
           let legacy = UserDefaults.standard.persistentDomain(forName: bundleId) {
            for (key, value) in legacy where group.object(forKey: key) == nil {
                group.set(value, forKey: key)
            }
        }

        group.set(true, forKey: appGroupKey)
    }

    private static func migrateFrom(_ from: Int, to: Int) {
        Occurrence.forget("telemetryUploaded")

        // ...
    }

    private static func currentBuild() -> Int {
        guard let string = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String, let build = Int(string) else {
            assertionFailure("Could not parse CFBundleVersion")

            return 0
        }

        return build
    }

    private static func storedSchema() -> Int? {
        let value = dependencies.store.integer(forKey: key)
        return value > 0 ? value : nil
    }

    private static func save(_ build: Int) {
        dependencies.store.set(build, forKey: key)
    }
}
