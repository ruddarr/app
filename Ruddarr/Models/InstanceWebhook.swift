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

    func update(_ accountId: CKRecord.ID?) async {
        await synchronize(accountId, update: true)
    }

    func synchronize(_ accountId: CKRecord.ID?, update: Bool = false) async {
        error = nil

        do {
            isSynchronizing = true

            if update {
                model = try await updateWebook(accountId!)
            } else {
                notifications = try await dependencies.api.fetchNotifications(instance)

                if let webhook = webhook() {
                    model = webhook
                } else {
                    if let userId = accountId {
                        model = try await createWebook(userId)
                        notifications.append(model)
                    }
                }
            }
        } catch is CancellationError {
            // do nothing
        } catch let urlError as URLError where urlError.code == .cancelled {
            // do nothing
        } catch {
            self.error = error

            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook synchronization failed", data: ["error": error])
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

    private func createWebook(_ account: CKRecord.ID) async throws -> InstanceNotification {
        let model = InstanceNotification(
            id: 0,
            name: "Ruddarr",
            fields: webhookFields(account)
        )

        return try await dependencies.api.createNotification(model, instance)
    }

    private func updateWebook(_ account: CKRecord.ID) async throws -> InstanceNotification {
        model.fields = webhookFields(account)

        return try await dependencies.api.updateNotification(model, instance)
    }

    private func webhookFields(_ account: CKRecord.ID) -> [InstanceNotificationField] {
        let url = URL(string: Notifications.url)!
            .appending(path: "/\(account.recordName)")
            .absoluteString

        return [
            InstanceNotificationField(name: "url", value: url),
            InstanceNotificationField(name: "method", value: "1"),
            InstanceNotificationField(name: "username", value: ""),
            InstanceNotificationField(name: "password", value: ""),
        ]
    }
}
