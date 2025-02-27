import os
import SwiftUI
import CloudKit
import StoreKit

struct InstanceView: View {
    var instance: Instance

    init(instance: Instance) {
        self.instance = instance
        self._webhook = State(wrappedValue: InstanceWebhook(instance))
    }

    @State var webhook: InstanceWebhook
    
    @State private var error: API.Error?
    @State var isLoadingLocationsDiskSpace: Bool = true
    @State var locationsDiskSpace: [InstanceLocationDiskSpace]?

    @State var notificationsAllowed: Bool = false
    @State var instanceNotifications: Bool = false
    @State var entitledToService: Bool = false
    @State var showSubscription: Bool = false
    @State var showEditForm: Bool = false
    @State var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @State var cloudKitUserId: CKRecord.ID?

    @State var showSonarrNoiseAlert = false

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            instanceDetails

            if !instance.headers.isEmpty {
                instanceHeaders
            }
            
            diskSpace
            notifications

            #if DEBUG
                Button {
                    Task { await Notifications.requestAuthorization() }
                } label: {
                    Text(verbatim: "Request Permissions")
                }
            #endif
        }
        .toolbar {
            toolbarEditButton
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .task {
            await setup()
            await fetchLocationsDiskSpace()
        }
        .onChange(of: instanceNotifications) {
            Task { await notificationsToggled() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await setup() }
            }
        }
        .subscriptionStatusTask(for: Subscription.group, action: handleSubscriptionStatusChange)
        .sheet(isPresented: $showSubscription) { RuddarrPlusSheet() }
        .alert(
            isPresented: webhook.errorBinding,
            error: webhook.error
        ) { _ in
            Button("OK") { webhook.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert(
            isPresented: Binding(
                get: { self.error != nil },
                set: { _ in }
            ),
            error: error
        ) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }
    
    private func fetchLocationsDiskSpace() async {
        defer {
            isLoadingLocationsDiskSpace = false
        }
        do {
            isLoadingLocationsDiskSpace = true
            locationsDiskSpace = try await dependencies.api.fetchLocationsDiskSpace(instance)
        } catch {
            self.error = API.Error(from: error)
        }
    }

    @ToolbarContentBuilder
    var toolbarEditButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            #if os(macOS)
                Button("Edit") {
                    showEditForm = true
                }
                .sheet(isPresented: $showEditForm) {
                    InstanceEditView(mode: .update, instance: instance)
                        .environment(radarrInstance)
                        .environment(sonarrInstance)
                        .environmentObject(settings)
                        .padding(.all)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showEditForm = false }
                            }
                        }
                }
            #else
                NavigationLink("Edit", value: SettingsView.Path.editInstance(instance.id))
            #endif
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
    
    @ViewBuilder
    var diskSpace: some View {
        Section {
            if let locationsDiskSpace {
                ForEach(locationsDiskSpace) { location in
                    LabeledContent(
                        location.path,
                        value: "\(location.freeSpace.formatBytes()) / \(location.totalSpace.formatBytes())"
                    )
                }
            } else if !isLoadingLocationsDiskSpace {
                LabeledContent("No locations found", value: "Tap to Reload")
                    .onTapGesture {
                        Task { await fetchLocationsDiskSpace() }
                    }
            }
        } header: {
            HStack(spacing: 4) {
                Text("Disk Space")
                
                if isLoadingLocationsDiskSpace {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }
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
