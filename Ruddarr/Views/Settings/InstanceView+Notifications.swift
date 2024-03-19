import SwiftUI
import CloudKit

extension InstanceView {
    var enableNotifications: some View {
        let text = String(
            format: String(localized: "Notification are disabled, please enable them in %@."),
            String(format: "[%@](#link)", String(localized: "Settings > Notifications > Ruddarr"))
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

            return .handled
        })
    }

    var disableNotifications: some View {
        let text = String(
            format: String(localized: "Notification settings for each instance are shared between devices. To disable notifications for a specific device go to %@."),
            String(format: "[%@](#link)", String(localized: "Settings > Notifications"))
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

            return .handled
        })
    }

    var subscribeToService: some View {
        let text = String(
            format: String(localized: "Notification require a subscription to %@."),
            "[\(Subscription.name)](#link)"
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            showSubscription = true

            return .handled
        })
    }

    var enableCloudKit: some View {
        let status = Telemetry.shared.cloudKitStatus(cloudKitStatus)

        return Text(
            "Notification require an iCloud account. Please sign into iCloud, or enable iCloud Drive in the iCloud settings (\(status)).",
            comment: "Placeholder is CloudKit status"
        )
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
            .onChange(of: webhook.model.onMovieAdded, updateWebhook)

            Toggle("Movie Downloading", isOn: $webhook.model.onGrab)
                .onChange(of: webhook.model.onGrab, updateWebhook)

            Toggle("Movie Downloaded", isOn: $webhook.model.onDownload)
                .onChange(of: webhook.model.onDownload, updateWebhook)

            Toggle("Movie Upgraded", isOn: $webhook.model.onUpgrade)
                .onChange(of: webhook.model.onUpgrade, updateWebhook)

            Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                .onChange(of: webhook.model.onHealthIssue, updateWebhook)

            Toggle("Health Restored", isOn: $webhook.model.onHealthRestored)
                .onChange(of: webhook.model.onHealthRestored, updateWebhook)

            Toggle("Application Updated", isOn: $webhook.model.onApplicationUpdate)
                .onChange(of: webhook.model.onApplicationUpdate, updateWebhook)
        }
    }

    var sonarrNotifications: some View {
        Group {
            Toggle("Series Added", isOn: Binding<Bool>(
                get: { self.webhook.model.onSeriesAdd ?? false },
                set: { newValue in self.webhook.model.onSeriesAdd = newValue }
            ))
            .onChange(of: webhook.model.onSeriesAdd, updateWebhook)

            Toggle("Episode Downloading", isOn: $webhook.model.onGrab)
                .onChange(of: webhook.model.onGrab, updateWebhook)

            Toggle(isOn: $webhook.model.onDownload) {
                HStack(spacing: 8) {
                    Text("Episode Downloaded")
                    Image(systemName: "info")
                        .symbolVariant(.circle)
                        .foregroundStyle(.secondary)
                        .onTapGesture { showSonarrNoiseAlert = true }
                        .alert("Noisy Action", isPresented: $showSonarrNoiseAlert) { } message: {
                            Text("This webhook action can be noisy.")
                        }
                }
            }
            .onChange(of: webhook.model.onDownload, updateWebhook)

            Toggle("Episode Upgraded", isOn: $webhook.model.onUpgrade)
                .onChange(of: webhook.model.onUpgrade, updateWebhook)

            Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                .onChange(of: webhook.model.onHealthIssue, updateWebhook)

            Toggle("Health Restored", isOn: $webhook.model.onHealthRestored)
                .onChange(of: webhook.model.onHealthRestored, updateWebhook)

            Toggle("Application Updated", isOn: $webhook.model.onApplicationUpdate)
                .onChange(of: webhook.model.onApplicationUpdate, updateWebhook)
        }
    }
}

extension InstanceView {
    func setup() async {
        await setAppNotificationsStatus()
        await setCloudKitAccountStatus()
        await setSubscriptionStatus()
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

    func setSubscriptionStatus() async {
        entitledToService = await Subscription.entitledToService()
    }

    func initialWebhookSync() async {
        if notificationsAllowed && cloudKitEnabled && entitledToService {
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

    func updateWebhook() {
        Task {
            await webhook.update(cloudKitUserId)
        }
    }
}
