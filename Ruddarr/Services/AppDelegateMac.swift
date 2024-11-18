import Sentry
import SwiftUI
import CloudKit
import MetricKit
import TelemetryDeck

#if os(macOS)
class AppDelegateMac: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        configureSentry()
        configureTelemetryDeck()
    }

    func configureSentry() {
        SentrySDK.start { options in
            options.enabled = true
            options.debug = false
            options.environment = runningIn().rawValue

            options.dsn = Secrets.SentryDsn
            options.sendDefaultPii = false

            // options.attachViewHierarchy = false
            options.swiftAsyncStacktraces = true

            options.enableSigtermReporting = true
            options.enableWatchdogTerminationTracking = true
            options.enableMetricKit = true
            options.enableAppHangTracking = false
            options.enableCaptureFailedRequests = false
            // options.enablePreWarmedAppStartTracing = true
            options.enableTimeToFullDisplayTracing = true

            options.tracesSampleRate = 1
            options.profilesSampleRate = 1
        }

        // SentrySDK.configureScope { scope in
        //     scope.setContext(value: [
        //         "identifier": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
        //     ], key: "device")
        // }

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

        TelemetryDeck.initialize(config: configuration)
    }
}
#endif
