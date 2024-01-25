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
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Telemetry.shared.maybeUploadTelemetry()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
