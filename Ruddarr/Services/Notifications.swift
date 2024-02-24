import os
import SwiftUI
import CloudKit

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
            let account = (try? await CKContainer.default().userRecordID().recordName) ?? ""

            let payload: [String: String] = [
                "account": account,
                "token": token,
            ]

            let hashedToken = "\(account):\(token)"
            let storedToken = UserDefaults.standard.string(forKey: "registeredDeviceToken")

            if storedToken == hashedToken {
                leaveBreadcrumb(.info, category: "notifications", message: "Device already registered", data: payload)
                return
            }

            let body = try JSONSerialization.data(withJSONObject: payload)

            var request = URLRequest(
                url: URL(string: Notifications.url)!.appending(path: "/register")
            )

            request.httpMethod = "POST"
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            if statusCode >= 400 {
                throw AppError("Bad status code: \(statusCode)")
            }

            UserDefaults.standard.set(hashedToken, forKey: "registeredDeviceToken")

            if let data = String(data: json, encoding: .utf8) {
                leaveBreadcrumb(.info, category: "notifications", message: "Device registered", data: ["status": statusCode, "response": data])
            }
        } catch {
            leaveBreadcrumb(.error, category: "notifications", message: "Device registration failed", data: ["error": error])
        }
    }
}

struct InstanceNotification: Identifiable, Codable {
    let id: Int
    let name: String?
    var implementation: String = "Webhook"
    var configContract: String = "WebhookSettings"
    var fields: [InstanceNotificationField] = []

    // Radarr only
    var onMovieAdded: Bool? = false

    // Sonarr only
    var onSeriesAdd: Bool? = false

    // `Grab`: Release sent to download client
    var onGrab: Bool = false

    // `Download`: Completed downloading release
    var onDownload: Bool = false

    // `Download`: Completed downloading upgrade (`isUpgrade`)
    var onUpgrade: Bool = false

    var onHealthIssue: Bool = false { didSet { includeHealthWarnings = onHealthIssue } }
    var onHealthRestored: Bool = false
    private(set) var includeHealthWarnings: Bool = false

    var onApplicationUpdate: Bool = false

    // Sends test emails only
    var onManualInteractionRequired: Bool = true

    var isEnabled: Bool {
        onGrab
        || onDownload
        || onUpgrade
        || onMovieAdded ?? false
        || onSeriesAdd ?? false
        || onHealthIssue
        || onHealthRestored
        || onApplicationUpdate
        || onManualInteractionRequired
    }

    mutating func disable() {
        onGrab = false
        onDownload = false
        onUpgrade = false
        onMovieAdded = false // Radarr
        onSeriesAdd = false // Sonarr
        onHealthIssue = false
        onHealthRestored = false
        includeHealthWarnings = false
        onApplicationUpdate = false
        onManualInteractionRequired = false
    }

    mutating func enable() {
        onGrab = true
        onDownload = true
        onUpgrade = true
        onMovieAdded = true // Radarr
        onSeriesAdd = true // Sonarr
        onHealthIssue = false
        onHealthRestored = false
        includeHealthWarnings = false
        onApplicationUpdate = false
        onManualInteractionRequired = true
    }
}

struct InstanceNotificationField: Codable {
    let name: String
    var value: String = ""

    enum CodingKeys: String, CodingKey {
        case name
        case value
    }

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)

        if let string = try? container.decode(String.self, forKey: .value) {
            value = string
        }
    }
}
