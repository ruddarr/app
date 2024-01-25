import os
import SwiftUI

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NetworkMonitor.shared.start()

        dependencies = .mock
#if DEBUG
#endif
    }

    var body: some Scene {
        let appBecameActivePublisher = NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )

        WindowGroup {
            ContentView()
                .onReceive(appBecameActivePublisher) { _ in
                    Telemetry.shared.maybeUploadTelemetry()
                }
                .environmentObject(AppSettings())
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication) -> Bool {
        URLSession.shared.configuration.waitsForConnectivity = true

        return true
    }
}

func logger(_ category: String = "default") -> Logger {
    return Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: category
    )
}
