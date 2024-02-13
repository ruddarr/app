import SwiftUI

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        dependencies = .mock
        #endif

        NetworkMonitor.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appWindowFrame()
                .withAppState()
        }
        .windowResizability(.contentSize)
    }
}
