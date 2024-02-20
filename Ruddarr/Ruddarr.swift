import SwiftUI

@main
struct Ruddarr: App {
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

struct Secrets {
    static var SentryDsn = "https://74d9cb1a161b33e8374c7339bbe0ce93@o4506759093354496.ingest.sentry.io/4506759109017600"
    static var TelemetryAppId = "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
}
