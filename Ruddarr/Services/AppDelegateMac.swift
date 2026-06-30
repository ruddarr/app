import Sentry
import SwiftUI
import CloudKit
import MetricKit
import TelemetryDeck
import UserNotifications

#if os(macOS)
class AppDelegateMac:
    NSObject,
    NSApplicationDelegate,
    MXMetricManagerSubscriber,
    UNUserNotificationCenterDelegate
{
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        MXMetricManager.shared.add(self)
        UNUserNotificationCenter.current().delegate = self

        NSWindow.allowsAutomaticWindowTabbing = false

        configureTelemetryDeck()
    }

    // Called after successful registration with APNs
    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.hexEncoded()

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

        if hideInForeground,
           let frontmostApplication = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let bundleIdentifier = Bundle.main.bundleIdentifier,
           frontmostApplication == bundleIdentifier
        {
            return []
        }

        return [.banner, .list, .sound]
    }

    // Called after a notification was tapped
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let payload = response.notification.request.content.userInfo

        if let deeplink = payload["deeplink"] as? String, let url = URL(string: deeplink) {
            NSWorkspace.shared.open(url)
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
#endif
