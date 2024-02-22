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
                .onOpenURL { url in
                    do {
                        try QuickActions.Deeplink(url: url)()
                    } catch {
                        dependencies.toast.show(AnyView(Text(error.localizedDescription))) // is this how we handle errors? I thought we had `handleErrors` convenience method on Toast.
                    }
                    
                }
        }
        .windowResizability(.contentSize)
        
    }
}

struct Secrets {
    static var SentryDsn = "https://47df7eb41059b96d7f10733d28442d3d@o4506759093354496.ingest.sentry.io/4506759167803392"
    static var TelemetryAppId = "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
}
