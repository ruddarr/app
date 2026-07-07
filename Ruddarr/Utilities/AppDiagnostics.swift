import Foundation
import CloudKit

struct AppDiagnostics: Equatable, Sendable {
    var subscription: String
    var entitled: String
    var entitledAt: String
    var pushAuthorization: String
    var iCloudAccount: String
    var locale: String
    var region: String

    static func load() async -> AppDiagnostics {
        let status = await Subscription.entitlementStatus()
        let entitled = await Subscription.entitledToService()
        let entitledAt = await Subscription.lastEntitledDate()
        let push = await Notifications.authorizationStatus()

        let iCloudAccount = dependencies.cloudkit == .live
            ? cloudKitStatusString(try? await CKContainer.default().accountStatus())
            : "mock"

        return AppDiagnostics(
            subscription: (status ?? .unknown).label.lowercased(),
            entitled: entitled ? "yes" : "no",
            entitledAt: entitledAt?.formatted(.iso8601) ?? "never",
            pushAuthorization: pushAuthorizationStatusString(push),
            iCloudAccount: iCloudAccount,
            locale: Locale.current.identifier,
            region: Locale.current.region?.identifier ?? "unknown"
        )
    }

    func exportLines() -> [String] {
        [
            "",
            "[App]",
            "Locale: \(locale)",
            "Region: \(region)",
            "",
            "[Notifications]",
            "Subscription: \(subscription)",
            "Entitled: \(entitled)",
            "Entitled At: \(entitledAt)",
            "Push Authorization: \(pushAuthorization)",
            "iCloud Account: \(iCloudAccount)",
        ]
    }
}
