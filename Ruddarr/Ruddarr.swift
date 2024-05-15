import SwiftUI

@main
struct Ruddarr: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegateMac.self) var appDelegate
    #else
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        #if DEBUG
        // dependencies = .mock
        #endif

        NetworkMonitor.shared.start()
    }

    var body: some Scene {
        #if os(macOS)
            Window(String("Ruddarr"), id: "ruddarr") {
                ContentView()
                    .withAppState()
                    .onOpenURL(perform: openDeeplink)
            }
            .defaultSize(width: 1_280, height: 768)
            .windowResizability(.contentSize)
        #else
            WindowGroup {
                ContentView()
                    .withAppState()
                    .onOpenURL(perform: openDeeplink)
            }
        #endif
    }

    func openDeeplink(url: URL) {
        do {
            try QuickActions.Deeplink(url: url)()
        } catch {
            dependencies.toast.show(.error(error.localizedDescription))
        }
    }
}

struct Links {
    static let AppShare = URL(string: "https://apps.apple.com/app/ruddarr/id6476240130")!
    static let AppStore = URL(string: "itms-apps://itunes.apple.com/app/id6476240130")!
    static let TestFlight = URL(string: "https://testflight.apple.com/join/WbWNuoos")!
    static let Discord = URL(string: "https://discord.gg/UksvtDQUBA")!

    static let GitHub = URL(string: "https://github.com/ruddarr/app")!
    static let GitHubDiscussions = URL(string: "https://github.com/ruddarr/app/discussions")!
}

struct Secrets {
    static let SentryDsn: String = "https://47df7eb41059b96d7f10733d28442d3d@o4506759093354496.ingest.sentry.io/4506759167803392"
    static let TelemetryAppId: String = "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
}

extension WhatsNew {
    static var version: String = "1.1.0"

    static var features: [WhatsNewFeature] = [
        .init(
            image: "tv",
            title: "Sonarr Support",
            subtitle: "Manage and monitor TV Series, seasons and episodes."
        ),
        .init(
            image: "line.3.horizontal.decrease",
            title: "Filter by Original Language",
            subtitle: "Releases can now be filtered by language when browsing interactive search results."
        ),
        .init(
            image: "ant",
            title: "Fixes & Improvements",
            subtitle: "Tuned, fixed and polished dozens of parts, everything is a little better than before."
        ),
    ]
}
