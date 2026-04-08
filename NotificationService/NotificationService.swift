import Sentry
import CryptoKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        SentrySDK.start { options in
            options.dsn = Secrets.SentryDsn
            options.sendDefaultPii = false
        }

        self.contentHandler = contentHandler

        #if os(macOS)
            self.bestAttemptContent = UNMutableNotificationContent.resolvedContent(from: request.content)
        #else
            self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        #endif

        if let bestAttemptContent = bestAttemptContent {
            if let attachment = request.attachment {
                bestAttemptContent.attachments = [attachment]
            }

            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

extension UNNotificationRequest {
    var attachment: UNNotificationAttachment? {
        let fileManager = FileManager.default

        guard let poster = content.userInfo["poster"] as? String else { return nil }
        guard let posterUrl = URL(string: poster) else { return nil }
        guard let posterData = poster.data(using: .utf8) else { return nil }

        let posterHash = Insecure.MD5
            .hash(data: posterData)
            .prefix(Insecure.MD5.byteCount)
            .map { String(format: "%02hhx", $0) }
            .joined()

        let fileUrl = fileManager.temporaryDirectory.appendingPathComponent(
            "ruddarr-poster-\(posterHash).\(posterUrl.pathExtension)"
        )

        if !fileManager.fileExists(atPath: fileUrl.absoluteString) {
            guard let imageData = try? Data(contentsOf: posterUrl) else { return nil }
            try? imageData.write(to: fileUrl, options: .atomic)
        }

        return try? UNNotificationAttachment(identifier: posterHash, url: fileUrl)
    }
}


extension UNMutableNotificationContent {
    static func resolvedContent(from original: UNNotificationContent) -> UNMutableNotificationContent {
        guard let aps = original.userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else {
            return (original.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        }

        let content = UNMutableNotificationContent()

        content.title = resolveLocalizedString(
            key: alert["title-loc-key"] as? String,
            args: alert["title-loc-args"] as? [Any],
            fallback: original.title
        )

        content.subtitle = resolveLocalizedString(
            key: alert["subtitle-loc-key"] as? String,
            args: alert["subtitle-loc-args"] as? [Any],
            fallback: original.subtitle
        )

        content.body = resolveLocalizedString(
            key: alert["loc-key"] as? String,
            args: alert["loc-args"] as? [Any],
            fallback: original.body
        )

        content.sound = original.sound
        content.badge = original.badge
        content.userInfo = original.userInfo
        content.categoryIdentifier = original.categoryIdentifier
        content.threadIdentifier = original.threadIdentifier

        if let interruptionLevel = aps["interruption-level"] as? String {
            switch interruptionLevel {
            case "passive": content.interruptionLevel = .passive
            case "active": content.interruptionLevel = .active
            case "time-sensitive": content.interruptionLevel = .timeSensitive
            case "critical": content.interruptionLevel = .critical
            default: content.interruptionLevel = original.interruptionLevel
            }
        } else {
            content.interruptionLevel = original.interruptionLevel
        }

        return content
    }

    static func resolveLocalizedString(key: String?, args: [Any]?, fallback: String) -> String {
        guard let key = key else { return fallback }

        let format = NSLocalizedString(key, comment: "")

        guard format != key else { return fallback }

        guard let args = args, !args.isEmpty else { return format }

        return String(format: format, arguments: args.map { "\($0)" as NSString })
    }
}
