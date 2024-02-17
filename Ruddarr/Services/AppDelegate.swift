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

            options.dsn = "https://74d9cb1a161b33e8374c7339bbe0ce93@o4506759093354496.ingest.sentry.io/4506759109017600"
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
            appID: "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
        )

        configuration.defaultUser = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        configuration.logHandler = LogHandler.stdout(.error)

        TelemetryManager.initialize(with: configuration)
    }

    //    func userNotificationCenter(
    //        _ center: UNUserNotificationCenter,
    //        willPresent notification: UNNotification,
    //        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    //    ) {
    //        print("11111")
    //        if let userInfo = notification.request.content.userInfo as? [String : AnyObject] {
    //            //
    //        }
    //        completionHandler(.banner)
    //    }
    //
    //    func userNotificationCenter(
    //        _ center: UNUserNotificationCenter,
    //        didReceive response: UNNotificationResponse,
    //        withCompletionHandler completionHandler: @escaping () -> Void
    //    ) {
    //        print("222222222222")
    //        if let userInfo = response.notification.request.content.userInfo as? [String : AnyObject] {
    //            ///
    //        }
    //        completionHandler()
    //    }
}
