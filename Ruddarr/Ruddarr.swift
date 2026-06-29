import SwiftUI
import CoreSpotlight
import TipKit
import Sentry

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
        // dependencies.api = .mock
        // dependencies.cloudkit = .mock
        // Tips.showAllTipsForTesting()
        #endif

        Migrations.run()

        #if !DEBUG
        // Keep the App Group instances mirror fresh when iCloud syncs a change from
        // another device while the app is running. In-app edits and launch are
        // already covered by `AppSettings.mirrorInstances`.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            Task { @MainActor in AppSettings.refreshInstancesMirror() }
        }
        #endif

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

        let deeplink: QuickActions.Deeplink? = switch parts[0] {
        case "movie": Movie.ID(parts[1]).map { .openMovie($0, parts[2]) }
        case "series": Series.ID(parts[1]).map { .openSeries($0, parts[2]) }
        default: nil
        }

        guard let deeplink else {
            return leaveBreadcrumb(.error, category: "spotlight", message: "Invalid identifier", data: ["openSearchableItem": identifier])
        }

        deeplink()
    }
}

extension WhatsNew {
    static let version: String = "2.0.0"

    // ----------------------------------------------------------------------------------------------⌄⌄⌄
    static let features: [WhatsNewFeature] = [
        .init(
            image: "arrow.down.circle",
            title: "Download Indicators",
            subtitle: "Display queue status for movies, seasons and episodes in various places."
        ),
        .init(
            image: "calendar",
            title: "Calendar Navigation",
            subtitle: "Switched to using sheets to display calendar items for better navigation."
        ),
        .init(
            image: "magnifyingglass",
            title: "Quick Look",
            subtitle: "Tap on media posters to preview it in full size using Quick Look."
        ),
        .init(
            image: "internaldrive",
            title: "Instance Details",
            subtitle: "View library statistics and disk space usage for each instances."
        ),
        .init(
            image: "bolt",
            title: "Performance",
            subtitle: "Improved image loading as well as grid filtering and sorting performance."
        ),
        .init(
            image: "ladybug",
            title: "Fixes & Improvements",
            subtitle: "Various internal code improvements and refinements for iPadOS."
        )
    ]
}

#Preview {
    ContentView()
        .withAppState()
}

#Preview("What's New") {
    @Previewable @State var show: Bool = true

    return NavigationView {
        Text(verbatim: "Cupidatat adipisicing elit dolor cillum.")
    }.sheet(isPresented: $show, content: {
        WhatsNewView()
            // .environment(\.sizeCategory, .extraExtraLarge)
    })
    .tint(.brown)
}
