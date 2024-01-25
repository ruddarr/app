import Foundation
import SwiftUI

extension EnvironmentValues {
    subscript<Key: EnvironmentKey>(key key: Key.Type = Key.self) -> Key where Key.Value == Key {
        get { self[Key.self] }
        set { self[Key.self] = newValue }
    }
}

extension EnvironmentValues {
    var switchToNewInstance: () -> Void {
        get {
            // we can make some of this syntax more tolerable but its extra work
            let tabRouter = self[key: TabRouter.self]
            let settingsRouter = self[key: SettingsView.Router.self]
            return {
                tabRouter.selectedTab = .settings
                Task { @MainActor in
                    try await Task.sleep(until: .now + .seconds(0.1))
                    assert(settingsRouter.path.isEmpty) // FUTURE: make a decision on whether its safe to switch to newInstance regardless of the fact that settings tab already had active navigation
                    settingsRouter.path = .init([SettingsView.Path.createInstance])
                }
            }
        }
    }
}
