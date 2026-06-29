import Foundation

extension UserDefaults {
    /// Shared App Group suite. Data written here is readable by app extensions
    /// (e.g. `NotificationService`). Must match the `com.apple.security.application-groups`
    /// entry in every target's entitlements and be registered for the team.
    static let appGroup = "group.com.ruddarr"

    /// The app's primary store. Backed by the shared App Group suite so that
    /// extensions can read the same settings. Falls back to `.standard` only if
    /// the suite can't be created (e.g. missing entitlement), which keeps the app
    /// functional while preventing a half-migrated split between two stores.
    static let live: UserDefaults = {
        UserDefaults(suiteName: appGroup) ?? .standard
    }()
}

extension UserDefaults {
    static var mock: UserDefaults {
        let suiteName = #file
        let inMemoryDefaults = UserDefaults(suiteName: suiteName)!

        inMemoryDefaults.removePersistentDomain(forName: suiteName)

        return inMemoryDefaults
    }
}

class Occurrence {
    enum Unit: Double {
        case seconds = 1
        case minutes = 60
        case hours = 3_600
        case days = 86_400
    }

    static func date(of key: String) -> Date? {
        let seconds = dependencies.store.double(forKey: key)
        guard seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func since(_ key: String, unit: Unit = .seconds) -> TimeInterval {
        let now = Date().timeIntervalSince1970
        let secondsSince = dependencies.store.double(forKey: key)

        return (now - secondsSince) / unit.rawValue
    }

    static func daysSince(_ key: String) -> TimeInterval {
        since(key, unit: .days)
    }

    static func hoursSince(_ key: String) -> TimeInterval {
        since(key, unit: .hours)
    }

    static func minutesSince(_ key: String) -> TimeInterval {
        since(key, unit: .minutes)
    }

    static func occurred(_ key: String) {
        dependencies.store.set(Date().timeIntervalSince1970, forKey: key)
    }

    static func forget(_ key: String) {
        dependencies.store.removeObject(forKey: key)
    }
}
