import Foundation

extension UserDefaults {
    static var live: UserDefaults { .standard }
}

// TODO: Our `.mock` UserDefaults are broken
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
    }

    static func since(_ key: String, unit: Unit = .seconds) -> TimeInterval {
        var seconds: TimeInterval = 0

        if let storedTimestamp = dependencies.store.object(forKey: key) as? TimeInterval {
            seconds = storedTimestamp
        }

        return (Date().timeIntervalSince1970 - seconds) / unit.rawValue
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
}
