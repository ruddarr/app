import os
import SwiftUI

struct InstanceRow: View {
    @Binding var instance: Instance

    @State private var connection: Connection = .pending
    @State private var webhook: Webhook = .pending
    @State private var notifications: Bool = false

    @EnvironmentObject var settings: AppSettings

    enum Connection {
        case pending
        case reachable
        case unreachable
    }

    enum Webhook {
        case pending
        case enabled
        case disabled
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 5) {
                Text(instance.label)

                if webhook != .pending {
                    Image(systemName: "bell")
                        .symbolVariant(
                            notifications && webhook == .enabled ? .none : .slash
                        )
                        .imageScale(.small)
                        .scaleEffect(0.95)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                switch connection {
                case .pending: Text("Connecting...")
                case .reachable: Text("Connected")
                case .unreachable: Text("Connection Failed").foregroundStyle(.red)
                }
            }
            .font(.footnote)
            .foregroundStyle(.gray)
        }.task {
            await checkInstanceConnection()
        }
    }

    func checkInstanceConnection() async {
        await checkNotificationsStatus()

        do {
            let lastCheck = "instanceCheck:\(instance.id)"

            if Occurrence.since(lastCheck) < 60 {
                connection = .reachable
                return
            }

            connection = .pending

            async let systemStatus = try dependencies.api.systemStatus(instance)
            async let rootFolders = try dependencies.api.rootFolders(instance)
            async let qualityProfiles = try dependencies.api.qualityProfiles(instance)

            let data = try await systemStatus

            instance.name = data.instanceName
            instance.version = data.version
            instance.rootFolders = try await rootFolders
            instance.qualityProfiles = try await qualityProfiles

            settings.saveInstance(instance)

            Occurrence.occurred(lastCheck)

            let webhook = InstanceWebhook(instance)
            await webhook.synchronize()
            self.webhook = webhook.isEnabled ? .enabled : .disabled

            connection = .reachable
        } catch is CancellationError {
            // do nothing
        } catch {
            connection = .unreachable

            leaveBreadcrumb(.error, category: "movies", message: "Instance check failed", data: ["error": error])
        }
    }

    func checkNotificationsStatus() async {
        let status = await Notifications.authorizationStatus()

        notifications = status == .authorized
    }
}
