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

    @EnvironmentObject var settings: AppSettings

    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
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
            if error.localizedDescription == "cancelled" {
                let _ = leaveBreadcrumb(.error, category: "cancelled", message: "InstanceView") // swiftlint:disable:this redundant_discardable_let
            }

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
                .textSelection(.enabled)
        }
    }

    var instanceHeaders: some View {
        Section(header: Text("Headers")) {
            ForEach(instance.headers) { header in
                LabeledContent(header.name) {
                    Text(header.value)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 92, alignment: .trailing)
                }
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            }
        }
    }

    var notifications: some View {
        Section {
            Toggle("Enable Notifications", isOn: $instanceNotifications)
                .tint(settings.theme.toggleTint)
                .disabled(!notificationsAllowed || !cloudKitEnabled || webhook.isSynchronizing)

            if instanceNotifications {
                Group {
                    if instance.type == .radarr {
                        radarrNotifications
                    }

                    if instance.type == .sonarr {
                        sonarrNotifications
                    }
                }
                .disabled(webhook.isSynchronizing)
                .tint(settings.theme.toggleTint)
                .padding(.leading)
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

    var radarrNotifications: some View {
        Group {
            Toggle("Movie Added", isOn: Binding<Bool>(
                get: { self.webhook.model.onMovieAdded ?? false },
                set: { newValue in self.webhook.model.onMovieAdded = newValue }
            ))
                .onChange(of: webhook.model.onMovieAdded) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Movie Downloading", isOn: $webhook.model.onGrab)
                .onChange(of: webhook.model.onGrab) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Movie Downloaded", isOn: $webhook.model.onDownload)
                .onChange(of: webhook.model.onDownload) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Movie Upgraded", isOn: $webhook.model.onUpgrade)
                .onChange(of: webhook.model.onUpgrade) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                .onChange(of: webhook.model.onHealthIssue) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Health Restored", isOn: $webhook.model.onHealthRestored)
                .onChange(of: webhook.model.onHealthRestored) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Application Update", isOn: $webhook.model.onApplicationUpdate)
                .onChange(of: webhook.model.onApplicationUpdate) { Task { await webhook.update(cloudKitUserId) } }
        }
    }

    var sonarrNotifications: some View {
        Group {
            Toggle("Series Added", isOn: Binding<Bool>(
                get: { self.webhook.model.onSeriesAdd ?? false },
                set: { newValue in self.webhook.model.onSeriesAdd = newValue }
            ))
                .onChange(of: webhook.model.onSeriesAdd) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Episode Downloading", isOn: $webhook.model.onGrab)
                .onChange(of: webhook.model.onGrab) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Episode Downloaded", isOn: $webhook.model.onDownload)
                .onChange(of: webhook.model.onDownload) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Episode Upgraded", isOn: $webhook.model.onUpgrade)
                .onChange(of: webhook.model.onUpgrade) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                .onChange(of: webhook.model.onHealthIssue) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Health Restored", isOn: $webhook.model.onHealthRestored)
                .onChange(of: webhook.model.onHealthRestored) { Task { await webhook.update(cloudKitUserId) } }

            Toggle("Application Update", isOn: $webhook.model.onApplicationUpdate)
                .onChange(of: webhook.model.onApplicationUpdate) { Task { await webhook.update(cloudKitUserId) } }
        }
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
            leaveBreadcrumb(.warning, category: "view.instance", message: "Failed to determine CloudKit account status", data: ["error": error])
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

        // enable some notifications, if none are enabled
        if instanceNotifications && !webhook.model.isEnabled {
            webhook.model.enable()
        }

        // disable all notifications
        if !instanceNotifications {
            webhook.model.disable()
        }

        await webhook.update(cloudKitUserId)
    }

    func maybeRequestNotificationAuthorization() async {
        guard instanceNotifications else {
            return
        }

        await Notifications.shared.requestAuthorization()
        UIApplication.shared.registerForRemoteNotifications()
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
