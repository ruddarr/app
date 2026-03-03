import Foundation

class Migration {
    static let key = "schemaVersion"

    static func run() {
        let current = currentBuild()
        let stored = storedSchema()

        if stored != current {
            migrateFrom(stored ?? 0, to: current)
            save(current)
        }
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
