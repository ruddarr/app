import Foundation

extension UserDefaults {
    static var live: UserDefaults { .standard }
}

extension UserDefaults {
    static var mock: UserDefaults {
        let suiteName = #file
        let inMemoryDefaults = UserDefaults(suiteName: suiteName)!
        inMemoryDefaults.removePersistentDomain(forName: suiteName)
        return inMemoryDefaults
    }
}
