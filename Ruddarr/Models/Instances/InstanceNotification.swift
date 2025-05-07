import Foundation

struct InstanceNotification: Identifiable, Codable {
    var id: Int?
    var name: String?
    var implementation: String = "Webhook"
    var configContract: String = "WebhookSettings"
    var fields: [InstanceNotificationField] = []

    // `Grab`: Release sent to download client
    var onGrab: Bool = false

    // `Download`: Completed downloading release
    var onDownload: Bool = false

    // `Download`: Completed downloading upgrade (`isUpgrade`)
    var onUpgrade: Bool = false

    // Radarr only
    var onMovieAdded: Bool? = false
    var onMovieDelete: Bool? = false
    var onMovieFileDelete: Bool? = false

    // Sonarr only
    var onSeriesAdd: Bool? = false
    var onSeriesDelete: Bool? = false
    var onEpisodeFileDelete: Bool? = false
    var onImportComplete: Bool? = false

    var onManualInteractionRequired: Bool? = false

    var onHealthIssue: Bool = false
    var onHealthRestored: Bool? = false
    var includeHealthWarnings: Bool = false

    var onApplicationUpdate: Bool = false

    var supportsOnGrab: Bool? = false
    var supportsOnDownload: Bool? = false
    var supportsOnUpgrade: Bool? = false
    var supportsOnRename: Bool? = false
    var supportsOnHealthIssue: Bool? = false
    var supportsOnHealthRestored: Bool? = false
    var supportsOnApplicationUpdate: Bool? = false

    // Radarr
    var supportsOnMovieAdded: Bool? = false
    var supportsOnMovieDelete: Bool? = false
    var supportsOnMovieFileDelete: Bool? = false
    var supportsOnMovieFileDeleteForUpgrade: Bool? = false

    // Sonarr
    var supportsOnSeriesAdd: Bool? = false
    var supportsOnSeriesDelete: Bool? = false
    var supportsOnEpisodeFileDelete: Bool? = false
    var supportsOnEpisodeFileDeleteForUpgrade: Bool? = false
    var supportsOnImportComplete: Bool? = false
    var supportsOnManualInteractionRequired: Bool? = false

    var isEnabled: Bool {
        onGrab
        || onDownload
        || onUpgrade
        || onMovieAdded ?? false
        || onSeriesAdd ?? false
        || onImportComplete ?? false
        || onHealthIssue
        || onHealthRestored ?? false
        || onManualInteractionRequired ?? false
        || onApplicationUpdate
    }

    mutating func disable() {
        onGrab = false
        onDownload = false
        onUpgrade = false
        onMovieAdded = false // Radarr
        onSeriesAdd = false // Sonarr
        onImportComplete = false // Sonarr
        onHealthIssue = false
        onHealthRestored = false
        includeHealthWarnings = false
        onManualInteractionRequired = false
        onApplicationUpdate = false
    }

    mutating func enable() {
        onGrab = supportsOnGrab == true
        onDownload = supportsOnDownload == true
        onUpgrade = supportsOnUpgrade == true
        onManualInteractionRequired = supportsOnManualInteractionRequired == true
        onMovieAdded = supportsOnMovieAdded == true // Radarr
        onSeriesAdd = supportsOnSeriesAdd == true // Sonarr
        onImportComplete = false // Sonarr
        onHealthIssue = false
        onHealthRestored = false
        includeHealthWarnings = false
        onApplicationUpdate = supportsOnApplicationUpdate == true
    }

    @MainActor
    var isRuddarrWebhook: Bool {
        guard implementation == "Webhook" else {
            return false
        }

        if let label = name, label.contains(Ruddarr.name) {
            return true
        }

        return fields.contains {
            $0.value.starts(with: Notifications.url)
        }
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

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)

        if let string = try? container.decode(String.self, forKey: .value) {
            value = string
        }
    }
}
