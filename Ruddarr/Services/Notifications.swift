import os
import SwiftUI
import CloudKit
import StoreKit
import CryptoKit
@preconcurrency import UserNotifications

actor Notifications {
    static let shared: Notifications = Notifications()
    static let url: String = "https://notify.ruddarr.com"

    private let center: UNUserNotificationCenter

    private init() {
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
                "signature": Notifications.signature("\(account):\(token)")
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

            guard [.appstore, .testflight].contains(runningIn()) else {
                leaveBreadcrumb(.info, category: "notifications", message: "Skip device token registration in \(runningIn().rawValue)")

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
        Task.detached { [settings] in
            let instances = await settings.instances

            let updateNeeded = instances.map {
                Occurrence.hoursSince("webhookUpdated:\($0.id)") >= 24
            }.contains(true)

            if !updateNeeded {
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

                let webhook = await InstanceWebhook(instance)

                await webhook.update(cloudKitUserId)

                if await webhook.error == nil {
                    Occurrence.occurred(lastUpdate)
                }
            }
        }
    }

    static func signature(_ message: String) -> String {
        guard let secret = Bundle.main.infoDictionary?["APNsKey"] as? String else {
            leaveBreadcrumb(.fatal, category: "notifications", message: "Failed to load APNs key")

            return "TESTING"
        }

        let key = SymmetricKey(data: Data(secret.utf8))
        let data = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)

        return Data(hmac).base64EncodedString()
    }
}

// swiftlint:disable closure_body_length
#Preview {
    let ruddarrTest = [
        String(format: localized("NOTIFICATION_TEST")),
        String(format: localized("NOTIFICATION_TEST_BODY")),
    ]

    let applicationUpdate = [
        String(format: localized("NOTIFICATION_APPLICATION_UPDATE"), "Synology"),
        "{payload.message}",
    ]

    let health = [
        String(format: localized("NOTIFICATION_HEALTH"), "Synology"),
        "{payload.message}",
    ]

    let healthRestored = [
        String(format: localized("NOTIFICATION_HEALTH_RESTORED"), "Synology"),
        "{payload.message}",
    ]

    let manualInteractionRequired = [
        String(format: localized("NOTIFICATION_MANUAL_INTERACTION_REQUIRED"), "Synology"),
        "{payload.downloadInfo.title}",
        "{payload.downloadStatusMessages[0].title}",
    ]

    func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    func notification(_ strings: [String]) -> some View {
        let cutoff = strings.count == 3 ? 2 : 1

        ForEach(strings.indices, id: \.self) { index in
            Text(verbatim: strings[index])
                .fontWeight(index < cutoff ? .bold : .regular)
        }
    }

    return ScrollView {
        VStack(alignment: .leading) {
            group("RuddarrTest")
            notification(ruddarrTest)
            Divider().padding(.vertical)

            group("ApplicationUpdate")
            notification(applicationUpdate)
            Divider().padding(.vertical)

            group("Health")
            notification(health)
            Divider().padding(.vertical)

            group("HealthRestored")
            notification(healthRestored)
            Divider().padding(.vertical)

            group("ManualInteractionRequired")
            notification(manualInteractionRequired)
            Divider().padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("Movie") {
    let movieAdded = [
        String(format: localized("NOTIFICATION_MOVIE_ADDED"), "Synology"),
        String(format: localized("NOTIFICATION_MOVIE_ADDED_BODY"), "Joker", "2024"),
    ]

    let movieGrab = [
        String(format: localized("NOTIFICATION_MOVIE_GRAB"), "Synology"),
        String(format: localized("NOTIFICATION_MOVIE_GRAB_SUBTITLE"), "Joker", "2024"),
        String(format: localized("NOTIFICATION_MOVIE_GRAB_BODY"), "WEBDL-1080p", "BHD"),
    ]

    let movieDownload = [
        String(format: localized("NOTIFICATION_MOVIE_DOWNLOAD"), "Synology"),
        String(format: localized("NOTIFICATION_MOVIE_DOWNLOAD_BODY"), "Joker", "2024"),
    ]

    let movieUpgrade = [
        String(format: localized("NOTIFICATION_MOVIE_UPGRADE"), "Synology"),
        String(format: localized("NOTIFICATION_MOVIE_UPGRADE_BODY"), "Joker", "2024"),
    ]

    func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    func notification(_ strings: [String]) -> some View {
        let cutoff = strings.count == 3 ? 2 : 1

        ForEach(strings.indices, id: \.self) { index in
            Text(verbatim: strings[index])
                .fontWeight(index < cutoff ? .bold : .regular)
        }
    }

    return ScrollView {
        VStack(alignment: .leading) {
            group("MovieAdded")
            notification(movieAdded)
            Divider().padding(.vertical)

            group("Grab")
            notification(movieGrab)
            Divider().padding(.vertical)

            group("Download")
            notification(movieDownload)
            Divider().padding(.vertical)

            group("Upgrade")
            notification(movieUpgrade)
            Divider().padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("Series") {
    let seriesAdd = [
        String(format: localized("NOTIFICATION_SERIES_ADDED"), "Synology"),
        String(format: localized("NOTIFICATION_SERIES_ADDED_BODY"), "Patriot", "2015"),
    ]

    let episodeGrab = [
        String(format: localized("NOTIFICATION_EPISODE_GRAB"), "Synology", "1"),
        String(format: localized("NOTIFICATION_EPISODES_GRAB_SUBTITLE"), "Patriot", "2"),
        String(format: localized("NOTIFICATION_EPISODES_GRAB_BODY"), "WEBDL-1080p", "BHD"),
    ]

    let episodesGrab = [
        String(format: localized("NOTIFICATION_EPISODES_GRAB"), "Synology", "8"),
        String(format: localized("NOTIFICATION_EPISODES_GRAB_SUBTITLE"), "Patriot", "2"),
        String(format: localized("NOTIFICATION_EPISODES_GRAB_BODY"), "WEBDL-1080p", "BHD"),
    ]

    let episodeDownload = [
        String(format: localized("NOTIFICATION_EPISODE_DOWNLOAD"), "Synology"),
        String(format: localized("NOTIFICATION_EPISODE_DOWNLOAD_BODY"), "Patriot", "2", "8"),
    ]

    let episodeUpgrade = [
        String(format: localized("NOTIFICATION_EPISODE_UPGRADE"), "Synology"),
        String(format: localized("NOTIFICATION_EPISODE_DOWNLOAD_BODY"), "Patriot", "2", "8"),
    ]

    let episodesDownload = [
        String(format: localized("NOTIFICATION_EPISODES_DOWNLOAD"), "Synology", "8"),
        String(format: localized("NOTIFICATION_EPISODES_DOWNLOAD_BODY"), "Patriot", "2"),
    ]

    let episodesUpgrade = [
        String(format: localized("NOTIFICATION_EPISODES_UPGRADE"), "Synology", "8"),
        String(format: localized("NOTIFICATION_EPISODES_DOWNLOAD_BODY"), "Patriot", "2"),
    ]

    func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    func notification(_ strings: [String]) -> some View {
        let cutoff = strings.count == 3 ? 2 : 1

        ForEach(strings.indices, id: \.self) { index in
            Text(verbatim: strings[index])
                .fontWeight(index < cutoff ? .bold : .regular)
        }
    }

    return ScrollView {
        VStack(alignment: .leading) {
            group("SeriesAdd")
            notification(seriesAdd)
            Divider().padding(.vertical)

            group("Grab (Episode)")
            notification(episodeGrab)
            Divider().padding(.vertical)

            group("Grab (Episodes)")
            notification(episodesGrab)
            Divider().padding(.vertical)

            group("Download (Episode)")
            notification(episodeDownload)
            Divider().padding(.vertical)

            group("Download (Episodes)")
            notification(episodesDownload)
            Divider().padding(.vertical)

            group("Upgrade (Episode)")
            notification(episodeUpgrade)
            Divider().padding(.vertical)

            group("Upgrade (Episodes)")
            notification(episodesUpgrade)
            Divider().padding(.vertical)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}
// swiftlint:enable closure_body_length
