import os
import SwiftUI
import CloudKit

@Observable
class InstanceWebhook {
    var instance: Instance
    var model: InstanceNotification = .init(id: 0, name: "")
    var error: Error?
    var isEnabled: Bool = false
    var isSynchronizing: Bool = false

    private var notifications: [InstanceNotification] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    enum Mode {
        case create
        case update
        case delete
    }

    func update(_ accountId: CKRecord.ID?) async {
        await synchronize(accountId, mode: .update)
    }

    func delete() async {
        await synchronize(nil, mode: .delete)
    }

    func synchronize(_ accountId: CKRecord.ID?, mode: Mode = .create) async {
        error = nil

        do {
            isSynchronizing = true

            switch mode {
            case .create: try await createWebook(accountId)
            case .update: try await updateWebook(accountId)
            case .delete: try await deleteWebook()
            }
        } catch is CancellationError {
            // do nothing
        } catch let urlError as URLError where urlError.code == .cancelled {
            // do nothing
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook synchronization failed", data: ["mode": mode, "error": error])
        }

        isEnabled = model.isEnabled
        isSynchronizing = false
    }

    private func webhook() -> InstanceNotification? {
        notifications.first(where: {
            $0.implementation == "Webhook" &&
            $0.fields.first(where: { $0.value.starts(with: Notifications.url) }) != nil
        })
    }

    private func createWebook(_ accountId: CKRecord.ID?) async throws {
        notifications = try await dependencies.api.fetchNotifications(instance)

        if let webhook = webhook() {
            model = webhook
            return
        }

        guard let account = accountId else {
            return
        }

        let record = InstanceNotification(
            id: 0, name: "Ruddarr", fields: webhookFields(account)
        )

        model = try await dependencies.api.createNotification(record, instance)

        notifications.append(model)
    }

    private func updateWebook(_ accountId: CKRecord.ID?) async throws {
        guard let account = accountId else {
            throw AppError("Missing CKRecord.ID")
        }

        model.fields = webhookFields(account)

        model = try await dependencies.api.updateNotification(model, instance)
    }

    private func deleteWebook() async throws {
        notifications = try await dependencies.api.fetchNotifications(instance)

        if let webhook = webhook() {
            _ = try await dependencies.api.deleteNotification(webhook, instance)
        }
    }

    private func webhookFields(_ accountId: CKRecord.ID) -> [InstanceNotificationField] {
        let identifier = String(
            format: "%d:%@",
            Date().timeIntervalSince1970,
            accountId.recordName
        )

        let encodedIdentifier = identifier.data(using: .utf8)?.base64EncodedString() ?? ""

        let url = URL(string: Notifications.url)!
            .appending(path: "/push/\(encodedIdentifier)")
            .absoluteString

        return [
            InstanceNotificationField(name: "url", value: url),
            InstanceNotificationField(name: "method", value: "1"),
            InstanceNotificationField(name: "username", value: ""),
            InstanceNotificationField(name: "password", value: ""),
        ]
    }
}
