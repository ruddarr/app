import SwiftUI
import MetricKit
import TelemetryClient

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MXMetricManagerSubscriber {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        let metricManager = MXMetricManager.shared
        metricManager.add(self)

        let configuration = TelemetryManagerConfiguration(
            appID: "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
        )

        // TODO: use cloudkit user id?
        TelemetryManager.initialize(with: configuration)

        URLSession.shared.configuration.waitsForConnectivity = true
        // URLSession.shared.configuration.timeoutIntervalForRequest = 5

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
