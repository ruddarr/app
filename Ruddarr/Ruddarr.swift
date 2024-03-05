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
                .onOpenURL(perform: openDeeplink)
        }
        .windowResizability(.contentSize)
    }

    func openDeeplink(url: URL) {
        do {
            try QuickActions.Deeplink(url: url)()
        } catch {
            dependencies.toast.show(.error(error.localizedDescription))
        }
    }
}

struct Secrets {
    static var SentryDsn: String = "https://47df7eb41059b96d7f10733d28442d3d@o4506759093354496.ingest.sentry.io/4506759167803392"
    static var TelemetryAppId: String = "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
    static var NotificationKey: String = "TESTING"
}
