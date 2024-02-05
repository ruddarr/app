import SwiftUI
import MetricKit

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
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
                .onChange(of: scenePhase) {
                    defer { shortcutItemToProcess = nil }
                    
                    switch scenePhase {
                    case .active:
                        switch shortcutItemToProcess.flatMap({ QuickAction(rawValue: $0.type) }) {
                        case .addMovie?:
                            dependencies.router.goToSearch()
                        case nil:
                            break
                        }
                    case .background:
                        addQuickActions()
                    case .inactive: fallthrough; @unknown default:
                        break
                    }
                }
        }
    }
    
    enum QuickAction: String, CaseIterable {
        case addMovie
        
        var title: String {
            switch self {
            case .addMovie:
                "Add Movie"
            }
        }
            var icon: UIApplicationShortcutIcon {
                switch self {
                case .addMovie:
                    UIApplicationShortcutIcon(type: .add)
                }
            }
    }
    func addQuickActions() {
        UIApplication.shared.shortcutItems = QuickAction.allCases.map {
            UIApplicationShortcutItem(type: $0.rawValue, localizedTitle: $0.title, localizedSubtitle: "", icon: $0.icon)
        }
    }
}

var shortcutItemToProcess: UIApplicationShortcutItem?
final class AppDelegate: NSObject, UIApplicationDelegate, MXMetricManagerSubscriber {
    func application(_ application: UIApplication) -> Bool {
        let metricManager = MXMetricManager.shared
        metricManager.add(self)

        URLSession.shared.configuration.waitsForConnectivity = true

        return true
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard let firstPayload = payloads.first else { return }
        print(firstPayload.dictionaryRepresentation())
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let firstPayload = payloads.first else { return }
        print(firstPayload.dictionaryRepresentation())
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
            if let shortcutItem = options.shortcutItem {
                shortcutItemToProcess = shortcutItem
            }
            
            let sceneConfiguration = UISceneConfiguration(name: "Scene Configuration", sessionRole: connectingSceneSession.role)
            sceneConfiguration.delegateClass = SceneDelegate.self
            
            return sceneConfiguration
        }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        shortcutItemToProcess = shortcutItem
    }
}

extension ShapeStyle where Self == Color {
    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
}
