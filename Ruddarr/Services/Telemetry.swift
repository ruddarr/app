import os
import SwiftUI
import CloudKit
import TelemetryClient

class Telemetry {
    static let shared: Telemetry = Telemetry()
    private let log: Logger = logger("telemetry")

    func maybeUploadTelemetry(settings: AppSettings) {
        let key = "lastTelemetryDate"

        let oneDayAgo = Calendar.current.date(
            byAdding: .hour,
            value: -24,
            to: Date()
        )!

        var lastTelemetryDate: Date = oneDayAgo

        if let storedDate = UserDefaults.standard.object(forKey: key) as? Date {
            lastTelemetryDate = storedDate
        }

        #if DEBUG
        lastTelemetryDate = oneDayAgo
        #endif

        let hoursSincePing = Calendar.current.dateComponents(
            [.hour],
            from: lastTelemetryDate,
            to: Date()
        ).hour!

        guard hoursSincePing > 12 else {
            self.log.notice("\(hoursSincePing) house since last ping")

            return
        }

        Task(priority: .background) {
            await uploadTelemetryData(settings: settings)

            UserDefaults.standard.set(Date(), forKey: key)
        }
    }

    private func uploadTelemetryData(settings: AppSettings) async {
        self.log.notice("Telemetry uploading...")

        let accountStatus = try? await CKContainer.default().accountStatus()

        await TelemetryManager.send("ping", with: [
            "icon": settings.icon.rawValue,
            "theme": settings.theme.rawValue,
            "appearance": settings.appearance.rawValue,
            "radarrInstances": String(settings.radarrInstances.count),
            "sonarrInstances": String(settings.sonarrInstances.count),
            "cloudkit": cloudKitStatus(accountStatus),
        ])
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
