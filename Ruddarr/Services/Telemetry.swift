import os
import Foundation
import CloudKit
import TelemetryDeck

@preconcurrency import Sentry

enum Metric: String {
    case ping

    case movieAdded
    case seriesAdded
    case artistAdded

    case movieDownloaded
    case seasonDownloaded
    case episodeDownloaded
    case albumDownloaded

    case movieSearchDispatched
    case seriesSearchDispatched
    case seasonSearchDispatched
    case episodeSearchDispatched
    case artistSearchDispatched
    case albumSearchDispatched
}

actor Telemetry {
    static func record(_ metric: Metric, attributes: [String: any Sentry.SentryAttributeValue] = [:]) {
        switch metric {
        case .movieDownloaded:
            SentrySDK.metrics.count(key: "releaseDownloaded", value: 1, attributes: ["type": "movie"])
        case .albumDownloaded:
            SentrySDK.metrics.count(key: "albumDownloaded", value: 1, attributes: ["type": "album"])
        case .seasonDownloaded:
            SentrySDK.metrics.count(key: "releaseDownloaded", value: 1, attributes: ["type": "season"])
        case .episodeDownloaded:
            SentrySDK.metrics.count(key: "releaseDownloaded", value: 1, attributes: ["type": "episode"])
        case .movieSearchDispatched:
            SentrySDK.metrics.count(key: "automaticSearchDispatched", value: 1, attributes: ["type": "movie"])
        case .seriesSearchDispatched:
            SentrySDK.metrics.count(key: "automaticSearchDispatched", value: 1, attributes: ["type": "series"])
        case .seasonSearchDispatched:
            SentrySDK.metrics.count(key: "automaticSearchDispatched", value: 1, attributes: ["type": "season"])
        case .episodeSearchDispatched:
            SentrySDK.metrics.count(key: "automaticSearchDispatched", value: 1, attributes: ["type": "episode"])
        case .artistSearchDispatched:
            SentrySDK.metrics.count(key: "automaticSearchDispatched", value: 1, attributes: ["type": "artists"])
        default:
            SentrySDK.metrics.count(key: metric.rawValue, value: 1, attributes: attributes)
        }
    }

    static func maybePing(with settings: AppSettings) {
        let hoursSincePing = Occurrence.hoursSince("telemetryUploaded")

        #if DEBUG
        // hoursSincePing = 24
        #endif

        guard hoursSincePing > 12 else {
            leaveBreadcrumb(.info, category: "telemetry", message: "Too early", data: ["hours": hoursSincePing])

            return
        }

        Task(priority: .background) {
            guard dependencies.cloudkit == .live else {
                leaveBreadcrumb(.info, category: "telemetry", message: "Skipping ping (CloudKit mock)")
                return
            }

            let accountStatus = try? await CKContainer.default().accountStatus()

            let payload: [String: String] = await [
                "icon": settings.icon.rawValue,
                "theme": settings.theme.rawValue,
                "tab": settings.tab.rawValue,
                "appearance": settings.appearance.rawValue,
                "grid": settings.grid.rawValue,
                "releaseFilters": settings.releaseFilters.rawValue,
                "deviceType": Platform.deviceType.rawValue,
                "lidarrInstances": String(settings.lidarrInstances.count),
                "radarrInstances": String(settings.radarrInstances.count),
                "sonarrInstances": String(settings.sonarrInstances.count),
                "cloudkit": cloudKitStatusString(accountStatus),
                "subscribed": String(await Subscription.entitledToService()),
            ]

            TelemetryDeck.signal("ping", parameters: payload)
            Telemetry.record(.ping, attributes: payload)
            Occurrence.occurred("telemetryUploaded")

            leaveBreadcrumb(.info, category: "telemetry", message: "Sent ping", data: payload)
        }
    }
}
