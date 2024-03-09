import os
import SwiftUI
import CloudKit
import TelemetryClient

class Telemetry {
    static let shared: Telemetry = Telemetry()

    func maybeUploadTelemetry(_ settings: AppSettings) {
        let lastUpload = "telemetryUploaded"
        let hoursSincePing = Occurrence.hoursSince(lastUpload)

        #if DEBUG
        // hoursSincePing = 24
        #endif

        guard hoursSincePing > 12 else {
            leaveBreadcrumb(.info, category: "telemetry", message: "Too early", data: ["hours": hoursSincePing])

            return
        }

        Task(priority: .background) {
            await uploadTelemetryData(settings: settings)

            Occurrence.occurred(lastUpload)
        }
    }

    private func uploadTelemetryData(settings: AppSettings) async {
        let accountStatus = try? await CKContainer.default().accountStatus()

        let payload: [String: String] = await [
            "icon": settings.icon.rawValue,
            "theme": settings.theme.rawValue,
            "appearance": settings.appearance.rawValue,
            "radarrInstances": String(settings.radarrInstances.count),
            "sonarrInstances": String(settings.sonarrInstances.count),
            "cloudkit": cloudKitStatus(accountStatus),
        ]

        TelemetryManager.send("ping", with: payload)

        leaveBreadcrumb(.info, category: "telemetry", message: "Sent ping", data: payload)
    }

    func cloudKitStatus(_ status: CKAccountStatus?) -> String {
        switch status {
        case .couldNotDetermine: "could-not-determine"
        case .available: "available"
        case .restricted: "restricted"
        case .noAccount: "no-account"
        case .temporarilyUnavailable: "temporarily-unavailable"
        case .none: "nil"
        @unknown default: "unknown"
        }
    }
}
