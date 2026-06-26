import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var showInstanceNameWarning: Bool = false
    @State private var showLocalNetworkWarning: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    enum Path: Hashable {
        case icons
        case changelog
        case createInstance
        case viewInstance(Instance.ID)
        case editInstance(Instance.ID)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.settingsPath) {
            Form {
                instanceSection

                SettingsPreferencesSection()
                SettingsDisplaySection()
                SettingsAboutSection()
                SettingsContributeSection()
                SettingsLinksSection()
                SettingsSystemSection()
            }
            .formStyle(.grouped)
            #if os(macOS)
                .labelReservedIconWidth(20)
            #endif
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                SettingsDestination(path: $0)
            }
        }
    }

    var instanceSection: some View {
        Section {
            ForEach($settings.instances) { $instance in
                NavigationLink(value: Path.viewInstance(instance.id)) {
                    InstanceRow(instance: $instance)
                }
            }

            addInstanceButton
        } header: {
            Text("Instances")
        } footer: {
            if showLocalNetworkWarning {
                localNetworkWarning
            } else if showInstanceNameWarning {
                instanceNameWarning
            }
        }.task {
            await checkInstance()
        }
    }

    var addInstanceButton: some View {
        NavigationLink(value: Path.createInstance) {
            Text("Add Instance")
        }
        #if os(macOS)
            .buttonStyle(.link)
            .foregroundStyle(settings.theme.tint)
        #endif
    }

    var instanceNameWarning: some View {
        Text("Notifications will not route reliably until each instance has been given a unique \"Instance Name\" in the web interface under \"Settings > General\".")
            .foregroundStyle(.orange)
    }

    var localNetworkWarning: some View {
        #if os(macOS)
            let settingsPath = String(localized: "System Settings > Privacy & Security > Local Network", comment: "macOS local network path")
        #else
            let settingsPath = String(localized: "System Settings", comment: "Settings app name")
        #endif

        let text = String(
            format: String(localized: "Local network access must be granted in %@ to connect to instances using private IP addresses."),
            "[\(settingsPath)](#link)"
        )

        var markdown = text.toMarkdown()

        for run in markdown.runs where run.link != nil {
            markdown[run.range].underlineStyle = .single
        }

        return Text(markdown)
            .foregroundStyle(.orange)
            .tint(.orange)
            .environment(\.openURL, .init { _ in
                #if os(macOS)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                        NSWorkspace.shared.open(url)
                    }
                #else
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                #endif

                return .handled
            })
    }

    func checkInstance() async {
        let status = await Notifications.authorizationStatus()
        let uniqueNames = Set(settings.instances.map { $0.name })

        if status == .authorized {
            showInstanceNameWarning = settings.instances.count != uniqueNames.count
        }

        let hasLocalInstances = settings.instances.contains { $0.isPrivateIp() }
        let localNetworkDenied = await NetworkMonitor.shared.localNetworkDenied

        showLocalNetworkWarning = hasLocalInstances && localNetworkDenied
    }
}

struct SettingsDestination: View {
    var path: SettingsView.Path

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    var body: some View {
        switch path {
        case .icons:
            IconsView()
                .environmentObject(settings)
        case .changelog:
            ChangelogView()
        case .createInstance:
            InstanceEditView(mode: .create, instance: Instance())
                .environment(radarrInstance)
                .environment(sonarrInstance)
                .environmentObject(settings)
        case .viewInstance(let instanceId):
            if let instance = settings.instanceById(instanceId) {
                InstanceView(instance: instance)
                    .environment(radarrInstance)
                    .environment(sonarrInstance)
                    .environmentObject(settings)
            }
        case .editInstance(let instanceId):
            if let instance = settings.instanceById(instanceId) {
                InstanceEditView(mode: .update, instance: instance)
                    .environment(radarrInstance)
                    .environment(sonarrInstance)
                    .environmentObject(settings)
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
