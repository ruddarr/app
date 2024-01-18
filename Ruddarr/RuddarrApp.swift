import SwiftUI

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NetworkMonitor.shared.start()

        #if DEBUG
        dependencies = .mock
        #endif

    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication) -> Bool {
        URLSession.shared.configuration.waitsForConnectivity = true

        return true
    }
}

extension Binding {
    var optional: Binding<Value?> {
        .init {
            wrappedValue
        } set: {
            if let value = $0 {
                wrappedValue = value
            }
        }
    }
}
