import Foundation

class Migration {
    static let buildKey = "buildNumber"

    // The first build to introduce this migration system; existing users upgrading
    // to this build will have no stored build number and still need migrations applied.
    static let firstMigrationBuild = 123

    static func run() {
        let current = currentBuild()
        let stored = storedBuild()

        guard stored != current else { return }

        if let stored {
            migrateOnChange()
            migrateFrom(stored, to: current)
        } else if current == firstMigrationBuild {
            migrateOnChange()
            migrateFrom(0, to: current)
        }

        save(current)
    }

    private static func migrateOnChange() {
        Occurrence.forget("telemetryUploaded")
    }

    private static func migrateFrom(_ from: Int, to: Int) {
        // empty – placeholder for future build-specific migrations
    }

    static func currentBuild() -> Int {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let build = Int(string)
        else {
            assertionFailure("Could not parse CFBundleVersion")
            return 0
        }

        return build
    }

    static func storedBuild() -> Int? {
        let value = dependencies.store.integer(forKey: buildKey)
        return value > 0 ? value : nil
    }

    static func save(_ build: Int) {
        dependencies.store.set(build, forKey: buildKey)
    }
}
