import Sentry
import SwiftUI
import CloudKit
import MetricKit
import TelemetryClient

// TODO: needs work (macOS)

#if os(macOS)
class AppDelegateMac: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        configureSentry()
        configureTelemetryDeck()
    }

    func configureSentry() {
        SentrySDK.start { options in
            options.enabled = true
            options.debug = false
            options.environment = environmentName()

            options.dsn = Secrets.SentryDsn
            options.sendDefaultPii = false

            // options.attachViewHierarchy = true
            options.swiftAsyncStacktraces = true

            options.enableMetricKit = true
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
                    "status": Telemetry.shared.cloudKitStatus(accountStatus),
                ], key: "cloudkit")
            }
        }
    }

    func configureTelemetryDeck() {
        let configuration = TelemetryManagerConfiguration(
            appID: Secrets.TelemetryAppId
        )

        configuration.logHandler = LogHandler.stdout(.error)

        TelemetryManager.initialize(with: configuration)
    }
}
#endif
