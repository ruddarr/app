import os
import SwiftUI
import CloudKit

@Observable
class InstanceWebhook {
    var instance: Instance
    var model: InstanceNotification = .init(id: 0, name: "")

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

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
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook \(mode) failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
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

    private func fetchWebhooks() async throws {
        notifications = try await dependencies.api.fetchNotifications(instance)
    }

    private func createWebook(_ accountId: CKRecord.ID?) async throws {
        try await fetchWebhooks()

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
        if model.id == 0 {
            try await createWebook(accountId)
        }

        guard let account = accountId else {
            throw AppError(String(localized: "Missing CloudKit user identifier."))
        }

        model.fields = webhookFields(account)

        model = try await dependencies.api.updateNotification(model, instance)
    }

    private func deleteWebook() async throws {
        try await fetchWebhooks()

        if let webhook = webhook() {
            _ = try await dependencies.api.deleteNotification(webhook, instance)
        }
    }

    private func webhookFields(_ accountId: CKRecord.ID) -> [InstanceNotificationField] {
        let time = Int(Date().timeIntervalSince1970)

        // change timestamp once a day at most
        let today = time - (time % 86_400)

        let identifier = "\(today):\(accountId.recordName)"
        let signature = Notifications.shared.signature(identifier)

        let encoded = identifier.data(using: .utf8)?.base64EncodedString() ?? "noop"

        let url = URL(string: Notifications.url)!
            .appending(path: "/push/\(encoded)")
            .absoluteString

        return [
            InstanceNotificationField(name: "url", value: url),
            InstanceNotificationField(name: "method", value: "1"),
            InstanceNotificationField(name: "username", value: ""),
            InstanceNotificationField(name: "password", value: signature),
        ]
    }
}
