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
