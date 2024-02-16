import os
import SwiftUI
import CloudKit

struct InstanceView: View {
    var instance: Instance

    init(instance: Instance) {
        self.instance = instance
        self._webhook = State(wrappedValue: InstanceWebhook(instance))
    }

    @State private var webhook: InstanceWebhook
    @State private var notificationsAllowed: Bool = false
    @State private var instanceNotifications: Bool = false
    @State private var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @State private var cloudKitUserId: CKRecord.ID?

    @Environment(\.scenePhase) private var scenePhase

    private let log: Logger = logger("settings.instance")

    var body: some View {
        List {
            instanceDetails

            if !instance.headers.isEmpty {
                instanceHeaders
            }

            notifications
        }
        .toolbar {
            toolbarEditButton
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await setup()
        }
        .onChange(of: instanceNotifications) {
            Task { await notificationsToggled() }
        }
        .onChange(of: scenePhase) { new, old in
            if new == .inactive && old == .active {
                Task { await setup() }
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { webhook.error != nil }, set: { _ in }),
            presenting: webhook.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    @ToolbarContentBuilder
    var toolbarEditButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            NavigationLink("Edit", value: SettingsView.Path.editInstance(instance.id))
        }
    }

    var instanceDetails: some View {
        Section {
            LabeledContent("Label", value: instance.label)
            LabeledContent("Type", value: instance.type.rawValue)
            LabeledContent("URL", value: instance.url)
        }
    }

    var instanceHeaders: some View {
        Section(header: Text("Headers")) {
            ForEach(instance.headers) { header in
                LabeledContent(header.name) {
                    Text(header.value)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 92)
                }
                .lineLimit(1)
                .truncationMode(.middle)
            }
        }
    }

    var notifications: some View {
        Section {
            Toggle("Enable Notifications", isOn: $instanceNotifications)
                .disabled(!notificationsAllowed || !cloudKitEnabled || webhook.isSynchronizing)

            if instanceNotifications {
                Toggle("Movie Grab", isOn: $webhook.model.onGrab)
                    .onChange(of: webhook.model.onGrab) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Movie Download", isOn: $webhook.model.onDownload)
                    .onChange(of: webhook.model.onDownload) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Movie Upgraded", isOn: $webhook.model.onUpgrade)
                    .onChange(of: webhook.model.onUpgrade) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Movie Added", isOn: $webhook.model.onMovieAdded)
                    .onChange(of: webhook.model.onMovieAdded) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                    .onChange(of: webhook.model.onHealthIssue) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Health Restored", isOn: $webhook.model.onHealthRestored)
                    .onChange(of: webhook.model.onHealthRestored) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)

                Toggle("Application Update", isOn: $webhook.model.onApplicationUpdate)
                    .onChange(of: webhook.model.onApplicationUpdate) { Task { await webhook.update(cloudKitUserId) } }
                    .disabled(webhook.isSynchronizing)
            }
        } header: {
            HStack(spacing: 4) {
                Text("Notifications")

                if webhook.isSynchronizing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }
            }
        } footer: {
            if !notificationsAllowed {
                enableNotifications
            } else if !cloudKitEnabled {
                enableCloudKit
            } else {
                disableNotifications
            }
        }
    }

    var enableNotifications: some View {
        Text("Notification are disabled, please enable them in [Settings > Notifications > Ruddarr](#link).")
            .environment(\.openURL, .init { _ in
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }

                return .handled
            })
    }

    var disableNotifications: some View {
        Text("Notification settings for each instance are shared between devices. To disable notifications for a specific device go to [Settings > Notifications](#link).")
            .environment(\.openURL, .init { _ in
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }

                return .handled
            })
    }

    var enableCloudKit: some View {
        let status = Telemetry.shared.cloudKitStatus(cloudKitStatus)

        return Text("Notification require an iCloud account. Please sign into iCloud, or enable iCloud Drive in the iCloud settings (\(status)).")
    }

    var cloudKitEnabled: Bool {
        cloudKitStatus == .available
    }
}

extension InstanceView {
    func setup() async {
        await setAppNotificationsStatus()
        await setCloudKitAccountStatus()
        await initialWebhookSync()
    }

    func setAppNotificationsStatus() async {
        let status = await Notifications.shared.authorizationStatus()

        switch status {
        case .denied:
            notificationsAllowed = false
            instanceNotifications = false
        case .notDetermined, .authorized:
            notificationsAllowed = true
        case .provisional, .ephemeral: break
        @unknown default: break
        }
    }

    func setCloudKitAccountStatus() async {
        do {
            let container = CKContainer.default()
            cloudKitStatus = try await container.accountStatus()
            cloudKitUserId = try? await container.userRecordID()
        } catch {
            log.warning("Failed to determine CloudKit account status: \(error.localizedDescription)")
        }
    }

    func initialWebhookSync() async {
        if notificationsAllowed && cloudKitEnabled {
            await webhook.synchronize(cloudKitUserId)

            instanceNotifications = webhook.isEnabled
        }
    }

    func notificationsToggled() async {
        await maybeRequestNotificationAuthorization()

        if !instanceNotifications {
            webhook.model.disable()
            await webhook.update(cloudKitUserId)
        }
    }

    func maybeRequestNotificationAuthorization() async {
        guard instanceNotifications else {
            return
        }

        await Notifications.shared.requestAuthorization()
        await UIApplication.shared.registerForRemoteNotifications()
        await setAppNotificationsStatus()
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.viewInstance(Instance.till.id)
    )

    return ContentView()
        .withAppState()
}
