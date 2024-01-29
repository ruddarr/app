import Foundation

extension UserDefaults {
    static var live: UserDefaults { .standard }
}

extension UserDefaults {
    static var mock: UserDefaults {
//        TODO: this doesn't really work, will need to debug unless we're moving away from AppStorage anyway. Im not using this for now
        let suiteName = #file
        let inMemoryDefaults = UserDefaults(suiteName: suiteName)!

//        inMemoryDefaults.removePersistentDomain(forName: suiteName)

        return inMemoryDefaults
    }
}
