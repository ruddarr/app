import SwiftUI
import CloudKit

extension InstanceView {
    var notificationPath: String {
        #if os(macOS)
            return String(format: "\"%@\"", String(localized: "System Settings > Notifications > \(Ruddarr.name)", comment: "macOS path"))
        #else
            return String(format: "[%@](#link)", String(localized: "System Settings", comment: "iOS path"))
        #endif
    }

    var enableNotifications: some View {
        let text = String(
            format: String(localized: "Notifications are disabled, please enable them in %@."),
            notificationPath
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            #if os(iOS)
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            #endif

            return .handled
        })
    }

    var disableNotifications: some View {
        let text = String(
            format: String(localized: "Notification settings for each instance are shared between devices. To disable notifications for a specific device go to %@."),
            notificationPath
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            #if os(iOS)
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            #endif

            return .handled
        })
    }

    var subscribeToService: some View {
        let text = String(
            format: String(localized: "Notifications require a subscription to %@."),
            "[\(Subscription.name)](#link)"
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text(text.toMarkdown())
            Text("Sending push notifications to devices requires reliable server infrastructure, which incurs monthly operating expenses for this free, open-source project.")
            Text("Alternatively, \(instance.type.rawValue) comes with many notification integrations that can be self-hosted.")
        }.environment(\.openURL, .init { _ in
            showSubscription = true

            return .handled
        })
    }

    var enableCloudKit: some View {
        let text = String(
            format: String(
                localized: "Notifications require an Apple Account. Please sign in, or enable iCloud Drive in the iCloud settings (%1$@).",
                comment: "1 = CloudKit status"
            ),
            cloudKitStatusString(cloudKitStatus)
        )

        return Text(text)
    }

    var cloudKitEnabled: Bool {
        cloudKitStatus == .available
    }

    // swiftlint:disable closure_body_length
    var radarrNotifications: some View {
        Group {
            if webhook.model.supportsOnMovieAdded ?? false {
                Toggle("Movie Added", isOn: Binding<Bool>(
                    get: { self.webhook.model.onMovieAdded ?? false },
                    set: { newValue in self.webhook.model.onMovieAdded = newValue }
                ))
                .onChange(of: webhook.model.onMovieAdded, updateWebhook)
            }

            if webhook.model.supportsOnGrab ?? false {
                Toggle("Movie Downloading", isOn: $webhook.model.onGrab)
                    .onChange(of: webhook.model.onGrab, updateWebhook)
            }

            if webhook.model.supportsOnDownload ?? false {
                Toggle("Movie Imported", isOn: $webhook.model.onDownload)
                    .onChange(of: webhook.model.onDownload, updateWebhook)
            }

            if webhook.model.onDownload && webhook.model.supportsOnUpgrade ?? false {
                Toggle("Movie Upgraded", isOn: $webhook.model.onUpgrade)
                    .onChange(of: webhook.model.onUpgrade, updateWebhook)
            }

            if webhook.model.supportsOnManualInteractionRequired ?? false {
                Toggle("Manual Interaction Required", isOn: Binding(
                    get: { webhook.model.onManualInteractionRequired ?? false },
                    set: { webhook.model.onManualInteractionRequired = $0 }
                ))
                .onChange(of: webhook.model.onManualInteractionRequired, updateWebhook)
            }

            if webhook.model.supportsOnHealthIssue ?? false {
                Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                    .onChange(of: webhook.model.onHealthIssue, updateWebhook)

                if webhook.model.onHealthIssue {
                    Toggle("Include Warnings", isOn: $webhook.model.includeHealthWarnings)
                        .onChange(of: webhook.model.includeHealthWarnings, updateWebhook)
                        .padding(.leading)
                }
            }

            if webhook.model.supportsOnHealthRestored ?? false {
                Toggle("Health Restored", isOn: Binding(
                    get: { webhook.model.onHealthRestored ?? false },
                    set: { webhook.model.onHealthRestored = $0 }
                ))
                .onChange(of: webhook.model.onHealthRestored, updateWebhook)
            }

            if webhook.model.supportsOnApplicationUpdate ?? false {
                Toggle("Application Updated", isOn: $webhook.model.onApplicationUpdate)
                    .onChange(of: webhook.model.onApplicationUpdate, updateWebhook)
            }
        }
    }

    var sonarrNotifications: some View {
        Group {
            if webhook.model.supportsOnSeriesAdd ?? false {
                Toggle("Series Added", isOn: Binding<Bool>(
                    get: { self.webhook.model.onSeriesAdd ?? false },
                    set: { newValue in self.webhook.model.onSeriesAdd = newValue }
                ))
                .onChange(of: webhook.model.onSeriesAdd, updateWebhook)
            }

            if webhook.model.supportsOnGrab ?? false {
                Toggle("Release Downloading", isOn: $webhook.model.onGrab)
                    .onChange(of: webhook.model.onGrab, updateWebhook)
            }

            if webhook.model.supportsOnDownload ?? false {
                Toggle("File Imported", isOn: $webhook.model.onDownload)
                    .onChange(of: webhook.model.onDownload, updateWebhook)
            }

            if webhook.model.onDownload && webhook.model.supportsOnUpgrade ?? false {
                Toggle("File Upgraded", isOn: $webhook.model.onUpgrade)
                    .onChange(of: webhook.model.onUpgrade, updateWebhook)
            }

            if webhook.model.supportsOnImportComplete ?? false {
                Toggle("Import Completed", isOn: Binding<Bool>(
                    get: { self.webhook.model.onImportComplete ?? false },
                    set: { newValue in self.webhook.model.onImportComplete = newValue }
                ))
                .onChange(of: webhook.model.onImportComplete, updateWebhook)
            }

            if webhook.model.supportsOnManualInteractionRequired ?? false {
                Toggle("Manual Interaction Required", isOn: Binding(
                    get: { webhook.model.onManualInteractionRequired ?? false },
                    set: { webhook.model.onManualInteractionRequired = $0 }
                ))
                .onChange(of: webhook.model.onManualInteractionRequired, updateWebhook)
            }

            if webhook.model.supportsOnHealthIssue ?? false {
                Toggle("Health Issue", isOn: $webhook.model.onHealthIssue)
                    .onChange(of: webhook.model.onHealthIssue, updateWebhook )

                if webhook.model.onHealthIssue {
                    Toggle("Include Warnings", isOn: $webhook.model.includeHealthWarnings)
                        .onChange(of: webhook.model.includeHealthWarnings, updateWebhook)
                        .padding(.leading)
                }
            }

            if webhook.model.supportsOnHealthRestored ?? false {
                Toggle("Health Restored", isOn: Binding(
                    get: { webhook.model.onHealthRestored ?? false },
                    set: { webhook.model.onHealthRestored = $0 }
                ))
                .onChange(of: webhook.model.onHealthRestored, updateWebhook)
            }

            if webhook.model.supportsOnApplicationUpdate ?? false {
                Toggle("Application Updated", isOn: $webhook.model.onApplicationUpdate)
                    .onChange(of: webhook.model.onApplicationUpdate, updateWebhook)
            }
        }
    }
    // swiftlint:enable closure_body_length
}

extension InstanceView {
    func setup() async {
        await setAppNotificationsStatus()
        await setCloudKitAccountStatus()
        await setSubscriptionStatus()
        await initialWebhookSync()
    }

    func setAppNotificationsStatus() async {
        let status = await Notifications.authorizationStatus()

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
        if dependencies.cloudkit == .mock {
            cloudKitStatus = .available
            cloudKitUserId = CKRecord.ID.mock

            return
        }

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
            await webhook.synchronize()

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

        await webhook.synchronize()
    }

    func maybeRequestNotificationAuthorization() async {
        guard instanceNotifications else {
            return
        }

        await Notifications.requestAuthorization()

        #if os(macOS)
            NSApplication.shared.registerForRemoteNotifications()
        #else
            UIApplication.shared.registerForRemoteNotifications()
        #endif

        await setAppNotificationsStatus()
    }

    func updateWebhook() {
        Task {
            await webhook.synchronize()
        }

        Occurrence.forget("instanceCheck:\(instance.id)")
    }
}
