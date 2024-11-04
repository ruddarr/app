import CryptoKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

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
