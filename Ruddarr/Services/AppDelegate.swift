import Sentry
import SwiftUI
import CloudKit
import MetricKit
import TelemetryClient

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MXMetricManagerSubscriber {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MXMetricManager.shared.add(self)
        UNUserNotificationCenter.current().delegate = self

        URLSession.shared.configuration.waitsForConnectivity = true

        configureSentry()
        configureTelemetryDeck()

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

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Task {
            await Notifications.shared.registerDevice(token)
        }
    }

    func configureSentry() {
        SentrySDK.start { options in
            options.enabled = true
            options.debug = false
            options.environment = environmentName()

            options.dsn = Secrets.SentryDsn
            options.sendDefaultPii = false

            options.attachViewHierarchy = true
            options.swiftAsyncStacktraces = true

            options.enableMetricKit = true
            options.enablePreWarmedAppStartTracing = true
            options.enableTimeToFullDisplayTracing = true

            options.tracesSampleRate = 1
            options.profilesSampleRate = 1
        }

        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "identifier": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            ], key: "device")
        }

        Task.detached {
            let container = CKContainer.default()
            let accountStatus = try? await container.accountStatus()
            let cloudKitUserId = try? await container.userRecordID()

            SentrySDK.configureScope { scope in
                scope.setContext(value: [
                    "user": cloudKitUserId?.recordName ?? "",
                    "status": Telemetry.shared.cloudKitStatus(accountStatus),
                ], key: "cloudkit")
            }
        }
    }

    func configureTelemetryDeck() {
        let configuration = TelemetryManagerConfiguration(
            appID: Secrets.TelemetryAppId
        )

        configuration.defaultUser = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        configuration.logHandler = LogHandler.stdout(.error)

        TelemetryManager.initialize(with: configuration)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
        
        let sceneConfiguration = UISceneConfiguration(name: "Scene Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = SceneDelegate.self
        
        return sceneConfiguration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
    }
}

fileprivate func handleShortcutItem(_ item: UIApplicationShortcutItem) {
    if let quickAction = QuickActions.Action(shortcutItem: item) {
        dependencies.quickActions.handle(quickAction)
    }
}
