import os
import SwiftUI
import CloudKit
import StoreKit
import CryptoKit

class Notifications {
    static let shared: Notifications = Notifications()
    static let url: String = "https://notify.ruddarr.com"

    private let center: UNUserNotificationCenter

    init() {
        center = UNUserNotificationCenter.current()
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            leaveBreadcrumb(.warning, category: "notifications", message: "Authorization request failed", data: ["status": error])
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()

        return settings.authorizationStatus
    }

    func registerDevice(_ token: String) async {
        do {
            let account = try await CKContainer.default().userRecordID().recordName
            let lastEntitledDate = await Subscription.lastEntitledDate()

            guard let entitledAt = lastEntitledDate?.timeIntervalSince1970 else {
                leaveBreadcrumb(.info, category: "notifications", message: "Device never been entitled to service")

                return
            }

            let payload: [String: AnyHashable] = [
                "account": account,
                "token": token,
                "entitledAt": Int(entitledAt),
                "signature": signature("\(account):\(token)")
            ]

            let lastTokenPing = "lastTokenPing:\(account):\(token)"

            if Occurrence.hoursSince(lastTokenPing) < 24 {
                leaveBreadcrumb(.info, category: "notifications", message: "Device token already registered", data: payload)

                return
            }

            var request = URLRequest(
                url: URL(string: Notifications.url)!.appending(path: "/register")
            )

            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            guard [.appstore, .testflight].contains(environment()) else {
                leaveBreadcrumb(.info, category: "notifications", message: "Skip device token registration in \(environmentName())")

                return
            }

            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            if statusCode >= 400 {
                throw AppError(String(localized: "Bad status code: \(statusCode)"))
            }

            Occurrence.occurred(lastTokenPing)

            if let data = String(data: json, encoding: .utf8) {
                leaveBreadcrumb(.info, category: "notifications", message: "Device registered", data: ["status": statusCode, "response": data])
            }
        } catch {
            leaveBreadcrumb(.error, category: "notifications", message: "Device registration failed", data: ["error": error])
        }
    }

    func maybeUpdateWebhooks(_ settings: AppSettings) {
        let instances = settings.instances

        let updateNeeded = instances.map {
            Occurrence.hoursSince("webhookUpdated:\($0.id)") >= 24
        }.contains(true)

        if !updateNeeded {
            return
        }

        Task.detached { [instances] in
            let notificationStatus = await Notifications.shared.authorizationStatus()

            if ![.authorized, .provisional, .ephemeral].contains(notificationStatus) {
                return
            }

            let cloudkit = CKContainer.default()
            let cloudKitStatus = try? await cloudkit.accountStatus()

            if cloudKitStatus != .available {
                return
            }

            guard let cloudKitUserId = try? await cloudkit.userRecordID() else {
                leaveBreadcrumb(.warning, category: "notifications", message: "CloudKit user record lookup failed")

                return
            }

            let entitledToService = await Subscription.entitledToService()

            if !entitledToService {
                return
            }

            for instance in instances {
                let lastUpdate = "webhookUpdated:\(instance.id)"

                if Occurrence.hoursSince(lastUpdate) < 24 {
                    continue
                }

                let webhook = InstanceWebhook(instance)

                await webhook.update(cloudKitUserId)

                if webhook.error == nil {
                    Occurrence.occurred(lastUpdate)
                }
            }
        }
    }

    func signature(_ message: String) -> String {
        let secret = Secrets.NotificationKey
        let key = SymmetricKey(data: Data(secret.utf8))
        let data = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)

        return Data(hmac).base64EncodedString()
    }
}
