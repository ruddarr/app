import os
import SwiftUI
import CloudKit
import TelemetryDeck

actor Telemetry {
    static let shared: Telemetry = Telemetry()

    func maybeUploadTelemetry(_ settings: AppSettings) {
        let hoursSincePing = Occurrence.hoursSince("telemetryUploaded")

        #if DEBUG
        // hoursSincePing = 24
        #endif

        guard hoursSincePing > 12 else {
            leaveBreadcrumb(.info, category: "telemetry", message: "Too early", data: ["hours": hoursSincePing])

            return
        }

        uploadTelemetryData(settings: settings)
    }

    private func uploadTelemetryData(settings: AppSettings) {
        Task(priority: .background) {
            let accountStatus = try? await CKContainer.default().accountStatus()

            let payload: [String: String] = await [
                "icon": settings.icon.rawValue,
                "theme": settings.theme.rawValue,
                "appearance": settings.appearance.rawValue,
                "deviceType": Platform.current.deviceType.rawValue,
                "radarrInstances": String(settings.radarrInstances.count),
                "sonarrInstances": String(settings.sonarrInstances.count),
                "cloudkit": cloudKitStatusString(accountStatus),
            ]

            TelemetryDeck.signal("ping", parameters: payload)
            Occurrence.occurred("telemetryUploaded")

            leaveBreadcrumb(.info, category: "telemetry", message: "Sent ping", data: payload)
        }
    }
}
