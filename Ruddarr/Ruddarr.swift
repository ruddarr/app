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
//         dependencies = .mock
//         dependencies.cloudkit = .mock
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
        case "artist": openDeeplink(url: URL(string: "ruddarr://artist/open/\(parts[1])?instance=\(parts[2])")!)
        default: leaveBreadcrumb(.error, category: "spotlight", message: "Invalid identifier", data: ["openSearchableItem": identifier])
        }
    }
}

extension WhatsNew {
    static let version: String = "1.9"

    // ----------------------------------------------------------------------------------------------⌄⌄⌄
    static let features: [WhatsNewFeature] = [
        .init(
            image: "music.note",
            title: "Lidarr",
            subtitle: "Added Lidarr integration support"
        ),
        .init(
            image: "gear",
            title: "Settings Moved",
            subtitle: "Settings have been moved to the toolbar at the top of each page on iPhone and iPad devices."
        )
    ]
}
