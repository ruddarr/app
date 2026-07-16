import os
import SwiftUI
import CloudKit
import StoreKit
import Sentry

struct InstanceView: View {
    var instance: Instance

    init(instance: Instance) {
        self.instance = instance
        self._webhook = State(wrappedValue: InstanceWebhook(instance))
    }

    @State var webhook: InstanceWebhook

    @State var entitledToService: Bool = false
    @State var showSubscription: Bool = false

    @State var notificationsAllowed: Bool = false
    @State var instanceNotifications: Bool = false

    @State var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @State var cloudKitUserId: CKRecord.ID?

    @State var version: String?
    @State var libraryState: MetadataState<InstanceStats> = .idle
    @State var libraryRefreshing: Bool = false
    @State var diskSpaceState: MetadataState<[InstanceDiskSpace]> = .idle
    @State var diskSpaceExpanded: Bool = false

    @Environment(AppSettings.self) var settings
    @Environment(RadarrInstance.self) var radarrInstance
    @Environment(SonarrInstance.self) var sonarrInstance

    var body: some View {
        Form {
            instanceDetails

            if !instance.headers.isEmpty {
                instanceHeaders
            }

            if !diskSpaceUnavailable {
                diskSpaceSection
            }

            notifications

            #if DEBUG
                Button {
                    Task { await Notifications.requestAuthorization() }
                } label: {
                    Text(verbatim: "Request Permissions")
                }
            #endif
        }
        .contentMargins(.bottom, 32, for: .scrollContent)
        .formStyle(.grouped)
        .toolbar {
            toolbarEditButton
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .task {
            await setup()
        }
        .onChange(of: instanceNotifications) {
            Task { await notificationsToggled() }
        }
        .onBecomeActive {
            await setup()
        }
        .sensoryAlert(
            isPresented: webhook.errorBinding,
            error: webhook.error
        ) { _ in
            Button("OK") { webhook.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .tint(nil)
        .subscriptionStatusTask(for: Subscription.group, action: handleSubscriptionStatusChange)
        .sheet(isPresented: $showSubscription) {
            RuddarrPlusSheet()
        }
    }

    func setup() async {
        async let summary: Void = loadSummary()

        await setAppNotificationsStatus()
        await setCloudKitAccountStatus()
        await setSubscriptionStatus()
        await initialWebhookSync()
        await summary
    }

    var instanceDetails: some View {
        Section {
            editRow {
                LabeledContent {
                    Text(instance.label)
                } label: {
                    Text("Label", comment: "Instance label/name")
                }
            }

            editRow {
                LabeledContent("Type", value: instance.type.rawValue)
            }

            editRow {
                LabeledContent("URL", value: instance.url)
            }

            editRow(advanced: instance.alternateURL.isEmpty) {
                LabeledContent("Alternate URL") {
                    if instance.alternateURL.isEmpty {
                        Text("Not Set").foregroundStyle(.secondary)
                    } else {
                        Text(instance.alternateURL)
                    }
                }
            }
        } footer: {
            metadataFooter
        }
    }

    func editRow<Content: View>(
        advanced: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture {
                dependencies.router.settingsPath.append(
                    SettingsView.Path.editInstance(instance.id, advanced: advanced)
                )
            }
    }

    var instanceHeaders: some View {
        Section(header: Text("Headers", comment: "HTTP Headers")) {
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
                .tint(settings.theme.safeTint)
                .disabled(!notificationsAllowed || !cloudKitEnabled || !entitledToService || webhook.isSynchronizing)

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
                .tint(settings.theme.safeTint)
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
            } else if !entitledToService {
                subscribeToService
            } else {
                disableNotifications
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarEditButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            NavigationLink(value: SettingsView.Path.editInstance(instance.id)) {
                Label("Edit", systemImage: "pencil")
                    .hideIconOnMac()
            }.tint(.primary)
        }
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        switch taskState {
        case .success(let statuses):
            entitledToService = Subscription.containsEntitledState(statuses)
            showSubscription = false
        case .failure(let error):
            leaveBreadcrumb(.fatal, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
            entitledToService = false
        case .loading: break
        @unknown default: break
        }
    }
}

#Preview {
    let settings = AppSettings()

    dependencies.router.selectedTab = .settings

    if let instance = settings.instances.first {
        dependencies.router.settingsPath.append(
            SettingsView.Path.viewInstance(instance.id)
        )
    }

    return ContentView()
        .withAppState()
}
