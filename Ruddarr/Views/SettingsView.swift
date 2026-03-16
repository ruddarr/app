import SwiftUI

struct SettingsView: View {
    @State private var showInstanceNameWarning: Bool = false
    @State private var showLocalNetworkWarning: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    enum Path: Hashable {
        case icons
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
                SettingsLinksSection()
                SettingsSystemSection()
            }
            .formStyle(.grouped)
            #if os(macOS)
                .labelReservedIconWidth(20)
            #endif
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .icons:
                    IconsView()
                        .environmentObject(settings)
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
                Text("Notifications will not route reliably until each instance has been given a unique \"Instance Name\" in the web interface under \"Settings > General\".")
                    .foregroundStyle(.orange)
            }
        }.task {
            await checkInstanceWarnings()
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

    var localNetworkWarning: some View {
        let settingsPath: String = {
            #if os(macOS)
                return String(format: "\"%@\"", String(localized: "System Settings > Privacy & Security > Local Network", comment: "macOS path"))
            #else
                return String(format: "[%@](#link)", String(localized: "System Settings", comment: "iOS path"))
            #endif
        }()

        let text = String(
            format: String(localized: "Local network access is denied. Allow it in %@ to connect to instances on private IP addresses."),
            settingsPath
        )

        return Text(text.toMarkdown())
            .foregroundStyle(.orange)
            .environment(\.openURL, .init { _ in
                #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                #endif

                return .handled
            })
    }

    func checkInstanceWarnings() async {
        let status = await Notifications.authorizationStatus()
        let uniqueNames = Set(settings.instances.map { $0.name })

        if status == .authorized {
            showInstanceNameWarning = settings.instances.count != uniqueNames.count
        }

        let hasLocalInstances = settings.instances.contains { $0.isPrivateIp() }
        showLocalNetworkWarning = hasLocalInstances && await NetworkMonitor.shared.isLocalNetworkDenied
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
