import os
import SwiftUI
import CloudKit

@MainActor
@Observable
class InstanceWebhook {
    var instance: Instance
    var accountId: CKRecord.ID?

    var model: InstanceNotification = .init()

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isEnabled: Bool = false
    var isSynchronizing: Bool = false

    private var notifications: [InstanceNotification] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    var webhook: InstanceNotification? {
        notifications.first { $0.isRuddarrWebhook }
    }

    func synchronize() async {
        guard !isSynchronizing else { return }

        error = nil
        isSynchronizing = true

        do {
            await fetchCloudKitUser()

            if notifications.isEmpty {
                try await fetchWebhooks()
            }

            if model.id == nil {
                try await createWebook()
            } else {
                try await updateWebook()
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook sync failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSynchronizing = false
        isEnabled = model.isEnabled
    }

    func delete() async {
        do {
            try await fetchWebhooks()

            if let webhook {
                _ = try await dependencies.api.deleteNotification(webhook, instance)
            }
        } catch {
            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook delete failed", data: ["error": error])
        }

        model = .init()
        notifications = []
    }

    private func fetchWebhooks() async throws {
        notifications = try await dependencies.api.fetchNotifications(instance)

        if let webhook {
            model = webhook
        }
    }

    private func createWebook() async throws {
        let record = InstanceNotification(
            name: Ruddarr.name,
            fields: webhookFields()
        )

        do {
            model = try await dependencies.api.createNotification(record, instance)
        } catch {
            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook creation failed", data: ["error": error])

            try? await fetchWebhooks()
            throw error
        }
    }

    private func updateWebook() async throws {
        model.name = Ruddarr.name
        model.fields = webhookFields()

        do {
            model = try await dependencies.api.updateNotification(model, instance)
        } catch {
            leaveBreadcrumb(.error, category: "instance.webhook", message: "Webhook update failed", data: ["error": error])

            throw error
        }
    }

    private func webhookFields() -> [InstanceNotificationField] {
        var url = URL(string: Notifications.url)!.appending(path: "/push")
        var payload: String = "noop"
        var signature: String = ""

        // change timestamp once a day at most
        let time = Int(Date().timeIntervalSince1970)
        let today: Int = time - (time % 86_400)

        if let account = accountId?.recordName {
            let identifier = "\(today):\(account)"

            payload = identifier.data(using: .utf8)!.base64EncodedString()
            signature = Notifications.signature(identifier)
        }

        url = url.appending(path: payload)

        return [
            InstanceNotificationField(name: "url", value: url.absoluteString),
            InstanceNotificationField(name: "method", value: "1"),
            InstanceNotificationField(name: "username", value: ""),
            InstanceNotificationField(name: "password", value: signature),
        ]
    }

    private func fetchCloudKitUser() async {
        if dependencies.cloudkit == .mock {
            accountId = CKRecord.ID(recordName: "_00000000000000000000000000000000")

            return
        }

        let cloudkit = CKContainer.default()
        let cloudKitStatus = try? await cloudkit.accountStatus()

        if cloudKitStatus != .available {
            return
        }

        guard let record = try? await cloudkit.userRecordID() else {
            leaveBreadcrumb(.error, category: "instance.webhook", message: "CloudKit user record lookup failed")

            return
        }

        accountId = record
    }
}
