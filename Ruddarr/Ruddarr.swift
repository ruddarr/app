import SwiftUI

// https://stackoverflow.com/questions/66043911/swiftui-app-how-to-hide-title-bar-for-macos-app
// https://stackoverflow.com/questions/49663728/how-to-hide-the-top-bar-with-buttons-usin-swift-and-macos?rq=4

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        // dependencies = .mock
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
