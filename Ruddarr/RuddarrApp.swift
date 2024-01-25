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
            let _ = dependencies.userDefaults.setValue((MovieSort(option: .byYear) as (any RawRepresentable)).rawValue, forKey: "movieSort")
            ContentView()
                .onReceive(appBecameActivePublisher) { _ in
                    Telemetry.shared.maybeUploadTelemetry()
                }
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
