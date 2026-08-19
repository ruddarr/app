import SwiftUI
import CloudKit
import CryptoKit
import Sentry
import UserNotifications

actor Notifications {
    static let url: String = "https://notify.ruddarr.com"

    static func requestAuthorization() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            leaveBreadcrumb(.warning, category: "notifications", message: "Authorization request failed", data: ["status": error])
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        return settings.authorizationStatus
    }

    static func registerDevice(_ token: String) async {
        do {
            let account = dependencies.cloudkit == .live
                ? try await CKContainer.default().userRecordID().recordName
                : CKRecord.ID.mock.recordName

            let lastEntitledDate = await Subscription.lastEntitledDate()

            guard let entitledAt = lastEntitledDate?.timeIntervalSince1970 else {
                leaveBreadcrumb(.info, category: "notifications", message: "Device never been entitled to service")

                return
            }

            let payload: [String: AnyHashable] = [
                "account": account,
                "token": token,
                "entitledAt": Int(entitledAt),
                "signature": Self.signature("\(account):\(token)")
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

    static func maybeUpdateWebhooks(_ settings: AppSettings) {
        Task.detached { [settings] in
            let instances = await settings.instances.filter(\.supportsNotifications)

            let updateNeeded = instances.map {
                Occurrence.hoursSince("webhookUpdated:\($0.id)") >= 6
            }.contains(true)

            if !updateNeeded {
                return
            }

            if dependencies.cloudkit == .live {
                let cloudkit = CKContainer.default()
                let cloudKitStatus = try? await cloudkit.accountStatus()

                if cloudKitStatus != .available {
                    return
                }
            }

            let entitledToService = await Subscription.entitledToService()

            if !entitledToService {
                return
            }

            for instance in instances {
                let lastUpdate = "webhookUpdated:\(instance.id)"

                if Occurrence.hoursSince(lastUpdate) < 6 {
                    continue
                }

                let webhook = await InstanceWebhook(instance)

                await webhook.synchronize()

                if await webhook.error == nil {
                    Occurrence.occurred(lastUpdate)
                }
            }
        }
    }

    static func signature(_ message: String) -> String {
        guard let secret = Bundle.main.object(forInfoDictionaryKey: "APNsKey") as? String else {
            leaveBreadcrumb(.fatal, category: "notifications", message: "Failed to load APNs key")

            return "TESTING"
        }

        let key = SymmetricKey(data: Data(secret.utf8))
        let data = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)

        return Data(hmac).base64EncodedString()
    }
}

// swiftlint:disable closure_body_length file_length
#Preview {
    let ruddarrTest = [
        localized("NOTIFICATION_TEST"),
        localized("NOTIFICATION_TEST_BODY"),
    ]

    let applicationUpdate = [
        localized("NOTIFICATION_APPLICATION_UPDATE", "Synology"),
        "{payload.message}",
    ]

    let health = [
        localized("NOTIFICATION_HEALTH", "Synology"),
        "{payload.message}",
    ]

    let healthRestored = [
        localized("NOTIFICATION_HEALTH_RESTORED", "Synology"),
        "{payload.message}",
    ]

    let manualInteractionRequired = [
        localized("NOTIFICATION_MANUAL_INTERACTION_REQUIRED", "Synology"),
        "{payload.downloadInfo.title}",
        "{payload.downloadStatusMessages[0].title}",
    ]

    func localized(_ key: String, _ args: any CVarArg...) -> String {
        unsafe String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
            Divider().padding(.top, 6)

            group("ApplicationUpdate")
            notification(applicationUpdate)
            Divider().padding(.top, 6)

            group("Health")
            notification(health)
            Divider().padding(.top, 6)

            group("HealthRestored")
            notification(healthRestored)
            Divider().padding(.top, 6)

            group("ManualInteractionRequired")
            notification(manualInteractionRequired)
            Divider().padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("Movie") {
    let movieAdded = [
        localized("NOTIFICATION_MOVIE_ADDED", "Synology"),
        localized("NOTIFICATION_MOVIE_ADDED_BODY", "Joker", "2024"),
    ]

    let movieGrab = [
        localized("NOTIFICATION_MOVIE_GRAB", "Synology"),
        localized("NOTIFICATION_MOVIE_GRAB_SUBTITLE", "Joker", "2024"),
        localized("NOTIFICATION_MOVIE_GRAB_BODY", "WEBDL-1080p", "BHD"),
    ]

    let movieDownload = [
        localized("NOTIFICATION_MOVIE_DOWNLOAD", "Synology"),
        localized("NOTIFICATION_MOVIE_DOWNLOAD_BODY", "Joker", "2024"),
    ]

    let movieUpgrade = [
        localized("NOTIFICATION_MOVIE_UPGRADE", "Synology"),
        localized("NOTIFICATION_MOVIE_UPGRADE_SUBTITLE", "Joker", "2024"),
        localized("NOTIFICATION_MOVIE_UPGRADE_BODY", "SDTV", "WEBDL-2160p"),
    ]

    let movieDowngrade = [
        localized("NOTIFICATION_MOVIE_DOWNGRADE", "Synology"),
        localized("NOTIFICATION_MOVIE_DOWNGRADE_BODY", "WEBDL-2160p", "SDTV"),
    ]

    let movieDeleted = [
        localized("NOTIFICATION_MOVIE_DELETED", "Synology"),
        localized("NOTIFICATION_MOVIE_DELETED_BODY", "Joker", "2024"),
    ]

    let movieFileDeleted = [
        localized("NOTIFICATION_MOVIE_FILE_DELETED", "Synology"),
        localized("NOTIFICATION_MOVIE_FILE_DELETED_BODY", "Joker", "2024"),
    ]

    func localized(_ key: String, _ args: any CVarArg...) -> String {
        unsafe String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
            Divider().padding(.top, 6)

            group("Grab")
            notification(movieGrab)
            Divider().padding(.top, 6)

            group("Download")
            notification(movieDownload)
            Divider().padding(.top, 6)

            group("Upgrade")
            notification(movieUpgrade)
            Divider().padding(.top, 6)

            group("Downgrade")
            notification(movieDowngrade)
            Divider().padding(.top, 6)

            group("Deleted")
            notification(movieDeleted)
            Divider().padding(.top, 6)

            group("FileDeleted")
            notification(movieFileDeleted)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("Series") {
    let seriesAdd = [
        localized("NOTIFICATION_SERIES_ADDED", "Synology"),
        localized("NOTIFICATION_SERIES_ADDED_BODY", "Patriot", "2015"),
    ]

    let seriesDelete = [
        localized("NOTIFICATION_SERIES_DELETED", "Synology"),
        localized("NOTIFICATION_SERIES_DELETED_BODY", "Patriot", "2015"),
    ]

    let episodeGrab = [
        localized("NOTIFICATION_EPISODE_GRAB", "Synology", "1"),
        localized("NOTIFICATION_EPISODE_GRAB_SUBTITLE", "Patriot", "2", "8"),
        localized("NOTIFICATION_EPISODES_GRAB_BODY", "WEBDL-1080p", "BHD"),
    ]

    let episodesGrab = [
        localized("NOTIFICATION_EPISODES_GRAB", "Synology", "8"),
        localized("NOTIFICATION_EPISODES_GRAB_SUBTITLE", "Patriot", "2"),
        localized("NOTIFICATION_EPISODES_GRAB_BODY", "WEBDL-1080p", "BHD"),
    ]

    let episodeDownload = [
        localized("NOTIFICATION_EPISODE_DOWNLOAD", "Synology"),
        localized("NOTIFICATION_EPISODE_DOWNLOAD_BODY", "Patriot", "2", "8"),
    ]

    let episodesDownload = [
        localized("NOTIFICATION_EPISODES_DOWNLOAD", "Synology", "8"),
        localized("NOTIFICATION_EPISODES_DOWNLOAD_BODY", "Patriot", "2"),
    ]

    let episodeUpgrade = [
        localized("NOTIFICATION_EPISODE_UPGRADE", "Synology"),
        localized("NOTIFICATION_EPISODE_UPGRADE_SUBTITLE", "Patriot", "2", "8"),
        localized("NOTIFICATION_EPISODE_UPGRADE_BODY", "SDTV", "WEBDL-2160p"),
    ]

    let episodeDowngrade = [
        localized("NOTIFICATION_EPISODE_DOWNGRADE", "Synology"),
        localized("NOTIFICATION_EPISODE_DOWNGRADE_BODY", "WEBDL-2160p", "SDTV"),
    ]

    let episodeFileDelete = [
        localized("NOTIFICATION_EPISODE_FILE_DELETED", "Synology"),
        localized("NOTIFICATION_EPISODE_FILE_DELETED_BODY", "Patriot", "2", "8"),
    ]

    func localized(_ key: String, _ args: any CVarArg...) -> String {
        unsafe String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }

    @ViewBuilder
    func group(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
            Divider().padding(.top, 6)

            group("SeriesDeleted")
            notification(seriesDelete)
            Divider().padding(.top, 6)

            group("Grab (Episode)")
            notification(episodeGrab)
            Divider().padding(.top, 6)

            group("Grab (Episodes)")
            notification(episodesGrab)
            Divider().padding(.top, 6)

            group("Download (Episode)")
            notification(episodeDownload)
            Divider().padding(.top, 6)

            group("Download (Episodes)")
            notification(episodesDownload)
            Divider().padding(.top, 6)

            group("Upgrade (Episode)")
            notification(episodeUpgrade)
            Divider().padding(.top, 6)

            group("Downgrade (Episode)")
            notification(episodeDowngrade)
            Divider().padding(.top, 6)

            group("Deleted (Episode File)")
            notification(episodeFileDelete)
            Divider().padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}
// swiftlint:enable closure_body_length file_length
