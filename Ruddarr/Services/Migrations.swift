import Foundation

class Migrations {
    static let key = "schemaVersion"
    static let appGroupKey = "migratedToAppGroup"

    static func run() {
        // Must run first: copies legacy `UserDefaults.standard` data into the App
        // Group suite so that everything below (schema version included) reads the
        // migrated values rather than re-running first-launch logic.
        migrateToAppGroup()

        let current = currentBuild()
        let stored = storedSchema()

        if stored != current {
            migrateFrom(stored ?? 0, to: current)
            save(current)
        }
    }

    /// One-time, idempotent copy of the app's own `UserDefaults.standard` domain
    /// into the shared App Group suite. Non-destructive: legacy values are left in
    /// place as a backup, and existing App Group values are never overwritten, so
    /// re-running (or running after a partial failure) can't lose or clobber data.
    private static func migrateToAppGroup() {
        let group = dependencies.store

        // Already migrated — the flag lives in the App Group itself.
        guard !group.bool(forKey: appGroupKey) else { return }

        // If the suite couldn't be created we fall back to `.standard` (same
        // instance). There's nothing to copy, and we must not set the flag yet so
        // the migration still runs once the entitlement is in place.
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
