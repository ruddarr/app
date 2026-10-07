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
        @Environment(\.scenePhase) private var scenePhase
    #endif

    nonisolated static let name: String = "Ruddarr"
    nonisolated static let group = "group.com.ruddarr"

    init() {
        #if DEBUG
        // dependencies.api = .mock
        // dependencies.cloudkit = .mock
        // Tips.showAllTipsForTesting()
        #endif

        Migrations.run()
        startSentry()
        InstancesStore.shared.start()

        dependencies.router.selectedTab = AppSettings.shared.tab

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
            .onChange(of: scenePhase, initial: true, Lifecycle.shared.phaseChanged)
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

        guard let item = SpotlightItemID(rawValue: identifier) else {
            return leaveBreadcrumb(.error, category: "spotlight", message: "Invalid identifier", data: ["openSearchableItem": identifier])
        }

        let deeplink: QuickActions.Deeplink = switch item.kind {
        case .movie: .openMovie(item.mediaId, item.instance)
        case .series: .openSeries(item.mediaId, item.instance)
        }

        deeplink()
    }
}

extension WhatsNew {
    static let version: String = "2.2.0"

    // ----------------------------------------------------------------------------------------------⌄⌄⌄
    static let features: [WhatsNewFeature] = [
        .init(
            image: "line.3.horizontal.decrease",
            title: "Custom Filters",
            subtitle: "Filter your movies and series with the custom filters you've saved in Radarr and Sonarr."
        ),
        .init(
            image: "bolt",
            title: "Faster Search",
            subtitle: "Searching large movie and series libraries is now close to instant."
        ),
        .init(
            image: "waveform",
            title: "Audio & Subtitle Tracks",
            subtitle: "See every audio and subtitle track in a movie's file details with Radarr 7.0.1 and later."
        ),
        .init(
            image: "square.stack.3d.up",
            title: "Multi-Season Packs",
            subtitle: "Sonarr multi-season packs are recognized, filterable and keep their type when imported manually."
        ),
        .init(
            image: "ladybug",
            title: "Improvements & Fixes",
            subtitle: "Subtitle flags, better codec names, exact Letterboxd links, and refinements for macOS and iPhone Duo."
        )
    ]
}

#Preview {
    ContentView()
        .withAppState()
}

#Preview("What's New") {
    @Previewable @State var show: Bool = true

    return NavigationStack {
        Text(verbatim: "Cupidatat adipisicing elit dolor cillum.")
    }.sheet(isPresented: $show, content: {
        WhatsNewView()
            // .environment(\.sizeCategory, .extraExtraLarge)
    })
    .tint(.brown)
}
