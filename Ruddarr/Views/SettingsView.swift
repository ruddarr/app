import SwiftUI

struct SettingsView: View {
    @State private var showInstanceForm: Bool = false
    @State private var showInstanceNameWarning: Bool = false

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
            List {
                instanceSection

                SettingsPreferencesSection()
                SettingsAboutSection()
                SettingsLinksSection()
                SettingsSystemSection()
            }
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
            if showInstanceNameWarning {
                Text("Notifications will not route reliably until each instance has been given a unique \"Instance Name\" in the web interface under \"Settings > General\".")
                    .foregroundStyle(.orange)
            }
        }.task {
            await checkInstanceName()
        }
    }

    var addInstanceButton: some View {
        #if os(iOS)
            NavigationLink(value: Path.createInstance) {
                Text("Add Instance")
            }
        #else
            Button("Add Instance") {
                showInstanceForm = true
            }
            .sheet(isPresented: $showInstanceForm) {
                InstanceEditView(mode: .create, instance: Instance())
                    .environment(radarrInstance)
                    .environment(sonarrInstance)
                    .environmentObject(settings)
                    .padding(.all)
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Close") { showInstanceForm = false }
                        }
                    }
            }
        #endif
    }

    func checkInstanceName() async {
        let status = await Notifications.authorizationStatus()
        let uniqueNames = Set(settings.instances.map { $0.name })

        if status == .authorized {
            showInstanceNameWarning = settings.instances.count != uniqueNames.count
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
