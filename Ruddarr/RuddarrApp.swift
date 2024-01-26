import SwiftUI

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        dependencies = .live
        #endif

        NetworkMonitor.shared.start()

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
                .withAppState()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication) -> Bool {
        URLSession.shared.configuration.waitsForConnectivity = true

        return true
    }
}
