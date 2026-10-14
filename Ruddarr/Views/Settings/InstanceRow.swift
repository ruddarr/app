import SwiftUI
import UserNotifications
import Sentry

struct InstanceRow: View {
    let instance: Instance

    @State private var connection: Connection = .pending
    @State private var currentURL: String = ""
    @State private var webhook: Webhook = .pending
    @State private var notifications: Bool = false
    @State private var networkToken: UUID?

    @Environment(AppSettings.self) private var settings

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

            statusText
                .font(.footnote)
                .foregroundStyle(connection == .unreachable ? Color.red : Color.gray)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .animation(.default, value: connection)
        .animation(.default, value: currentURL)
        .task {
            await checkNotificationsStatus()
        }
        .task(id: networkToken) {
            if networkToken != nil {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
            }

            await checkInstanceConnection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkChanged)) { _ in
            networkToken = UUID()
        }
    }

    private var statusText: Text {
        let multiURL = instance.candidateURLs.count > 1 && !currentURL.isEmpty

        switch connection {
        case .pending:
            return multiURL ? Text("Connecting to \(currentURL)...") : Text("Connecting...")
        case .reachable:
            return multiURL ? Text("Connected to \(currentURL)") : Text("Connected")
        case .unreachable:
            return Text("Connection Failed")
        }
    }

    private func hostPort(_ urlString: String) -> String {
        guard let components = URLComponents(string: urlString), let host = components.host else {
            return urlString
        }

        if let port = components.port {
            return "\(host):\(port)"
        }

        return host
    }

    func checkInstanceConnection() async {
        let selection = hostPort(await InstanceResolver.shared.currentSelection(for: instance))

        do {
            let lastCheck = "instanceCheck:\(instance.id)"

            if connection == .reachable, selection == currentURL, Occurrence.since(lastCheck) < 60 {
                return
            }

            currentURL = selection
            connection = .pending

            async let systemStatus = try dependencies.api.instance.status(instance)
            async let rootFolders = try dependencies.api.instance.rootFolders(instance)
            async let qualityProfiles = try dependencies.api.instance.qualityProfiles(instance)
            async let tags = dependencies.api.instance.tags(instance)

            let data = try await systemStatus
            let folders = try await rootFolders
            let profiles = try await qualityProfiles
            let instanceTags = try await tags

            guard !Task.isCancelled, var updated = settings.instanceById(instance.id),
                  updated.configuration == instance.configuration
            else { return }

            // Merge into the current record so a late response cannot undo edits or other metadata updates.
            updated.name = data.instanceName
            updated.version = data.version
            updated.rootFolders = folders
            updated.qualityProfiles = profiles
            updated.tags = instanceTags

            settings.saveInstance(updated)

            Occurrence.occurred(lastCheck)

            let webhook = InstanceWebhook(updated)
            await webhook.synchronize()

            let selectedURL = hostPort(await InstanceResolver.shared.currentSelection(for: instance))
            try Task.checkCancellation()

            self.webhook = webhook.isEnabled ? .enabled : .disabled
            currentURL = selectedURL
            connection = .reachable
        } catch is CancellationError {
            // do nothing
        } catch {
            guard !Task.isCancelled else { return }

            connection = .unreachable

            leaveBreadcrumb(.error, category: "movies", message: "Instance check failed", data: ["error": error])
        }
    }

    func checkNotificationsStatus() async {
        let status = await Notifications.authorizationStatus()

        notifications = status == .authorized
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
