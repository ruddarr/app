import SwiftUI
import CoreSpotlight
import TipKit

@main
struct Ruddarr: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegateMac.self) var appDelegate
    #else
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    nonisolated static let name: String = "Ruddarr"

    init() {
        #if DEBUG
        // dependencies = .mock
        // dependencies.cloudkit = .mock
        // Tips.showAllTipsForTesting()
        #endif

        Migrations.run()

        try? Tips.configure()

        Task {
            await NetworkMonitor.shared.start()
        }
    }

    var body: some Scene {
        #if os(macOS)
            Window(String(""), id: "ruddarr") {
                ContentView()
                    .frame(minWidth: 1_024, minHeight: 600)
                    .withAppState()
                    .onOpenURL(perform: openDeeplink)
                    .onContinueUserActivity(CSSearchableItemActionType, perform: openSearchableItem)
            }
            .defaultSize(width: 1_280, height: 768)
            .windowResizability(.contentSize)
        #else
            WindowGroup {
                ContentView()
                    .withAppState()
                    .onOpenURL(perform: openDeeplink)
                    .onContinueUserActivity(CSSearchableItemActionType, perform: openSearchableItem)
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

    func openSearchableItem(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

        let parts = identifier.split(separator: ":").map(String.init) // `<type>:<id>:<instance>`

        switch parts[0] {
        case "movie": openDeeplink(url: URL(string: "ruddarr://movies/open/\(parts[1])?instance=\(parts[2])")!)
        case "series": openDeeplink(url: URL(string: "ruddarr://series/open/\(parts[1])?instance=\(parts[2])")!)
        default: leaveBreadcrumb(.error, category: "spotlight", message: "Invalid identifier", data: ["openSearchableItem": identifier])
        }
    }
}

extension WhatsNew {
    static let version: String = "1.8.1"

    static let features: [WhatsNewFeature] = [
        .init(
            image: "globe",
            title: "New Translations",
            subtitle: "Italian and Turkish translations have been added."
        ),
        .init(
            image: "eye.slash",
            title: "Faded Unmonitored Items",
            subtitle: "Items already in your library or calendar that are unmonitored now appear faded."
        ),
        .init(
            image: "film.stack",
            title: "Dual Audio in Multi",
            subtitle: "Releases with dual audio are now included in the \"Multi\" language filter."
        ),
        .init(
            image: "ladybug",
            title: "Fixes & Improvements",
            subtitle: "Various internal code improvements, bug fixes, and macOS refinements."
        ),
    ]
}
