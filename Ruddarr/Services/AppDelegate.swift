import Sentry
import SwiftUI
import CloudKit
import MetricKit
import TelemetryDeck

#if os(iOS)
class AppDelegate:
    NSObject,
    UIApplicationDelegate,
    MXMetricManagerSubscriber,
    @preconcurrency UNUserNotificationCenterDelegate
{
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

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            handleShortcutItem(shortcutItem)
        }

        let sceneConfiguration = UISceneConfiguration(
            name: "Scene Configuration",
            sessionRole: connectingSceneSession.role
        )

        sceneConfiguration.delegateClass = SceneDelegate.self

        return sceneConfiguration
    }

    // Called after successful registration with APNs
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Task {
            await Notifications.registerDevice(token)
        }
    }

    // Called when the app receives a notification and is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard await Subscription.entitledToService() else {
            return []
        }

        let userInfo = notification.request.content.userInfo
        let hideInForeground = userInfo["hideInForeground"] as? Bool ?? false

        if hideInForeground && UIApplication.shared.applicationState == .active {
            return []
        }

        return [.banner, .list, .sound]
    }

    // Called after a notification was tapped
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let payload = response.notification.request.content.userInfo

        if let deeplink = payload["deeplink"] as? String, let url = URL(string: deeplink) {
            UIApplication.shared.open(url)
        }

        completionHandler()
    }

    func configureSentry() {
        SentrySDK.start { options in
            options.enabled = true
            options.debug = false
            options.environment = runningIn().rawValue

            options.dsn = Secrets.SentryDsn
            options.sendDefaultPii = false

            options.attachViewHierarchy = false
            options.swiftAsyncStacktraces = true

            options.enableSigtermReporting = true
            options.enableWatchdogTerminationTracking = true
            options.enableMetricKit = true
            // options.enableAppHangTracking = true
            options.enableAppHangTrackingV2 = false
            options.appHangTimeoutInterval = 3
            options.enableCaptureFailedRequests = false
            options.enablePreWarmedAppStartTracing = true
            options.enableTimeToFullDisplayTracing = true
            options.enablePersistingTracesWhenCrashing = true

            options.tracesSampleRate = 1
            options.profilesSampleRate = 1
        }

        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "identifier": Platform.deviceId,
            ], key: "device")
        }

        Task.detached {
            let container = CKContainer.default()
            let accountStatus = try? await container.accountStatus()
            let cloudKitUserId = try? await container.userRecordID()

            SentrySDK.configureScope { scope in
                scope.setContext(value: [
                    "user": cloudKitUserId?.recordName ?? "",
                    "status": cloudKitStatusString(accountStatus),
                ], key: "cloudkit")
            }
        }
    }

    func configureTelemetryDeck() {
        let configuration = TelemetryDeck.Config(
            appID: Secrets.TelemetryAppId
        )

        configuration.defaultUser = Platform.deviceId

        TelemetryDeck.initialize(config: configuration)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        handleShortcutItem(shortcutItem)
    }
}

private func handleShortcutItem(_ item: UIApplicationShortcutItem) {
    QuickActions.ShortcutItem(shortcutItem: item)?()
}
#endif
