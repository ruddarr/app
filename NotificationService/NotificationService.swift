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

        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            #if os(macOS)
                bestAttemptContent.resolveLocalizedStrings(from: request.content.userInfo)
            #endif

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

// macOS does not substitute loc-args that contain JSON numbers (e.g. year)
// into localized format strings. Manually resolve using NSLocalizedString
// (requires Localizable.xcstrings in the extension target's resources).
extension UNMutableNotificationContent {
    func resolveLocalizedStrings(from userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else { return }

        title = Self.resolve(
            key: alert["title-loc-key"] as? String,
            args: alert["title-loc-args"] as? [Any],
            fallback: title
        )

        subtitle = Self.resolve(
            key: alert["subtitle-loc-key"] as? String,
            args: alert["subtitle-loc-args"] as? [Any],
            fallback: subtitle
        )

        body = Self.resolve(
            key: alert["loc-key"] as? String,
            args: alert["loc-args"] as? [Any],
            fallback: body
        )
    }

    private static func resolve(key: String?, args: [Any]?, fallback: String) -> String {
        guard let key = key else { return fallback }

        let format = NSLocalizedString(key, comment: "")
        guard format != key else { return fallback }
        guard let args = args, !args.isEmpty else { return format }

        return String(format: format, arguments: args.map { "\($0)" as NSString })
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
