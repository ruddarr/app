import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) var instance

    enum Path: Hashable {
        case icons
        case libraries
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
                SettingsSystemSection()
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .icons:
                    IconsView()
                        .environmentObject(settings)
                        .environment(instance)

                case .libraries:
                    LibrariesView()
                        .environmentObject(settings)
                        .environment(instance)
                case .createInstance:
                    InstanceEditView(mode: .create, instance: Instance())
                        .environmentObject(settings)
                        .environment(instance)

                case .viewInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceView(instance: instance)
                            .environmentObject(settings)
                            .environment(self.instance)
                    }

                case .editInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceEditView(mode: .update, instance: instance)
                            .environmentObject(settings)
                            .environment(self.instance)
                    }
                }
            }
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach($settings.instances) { $instance in
                NavigationLink(value: Path.viewInstance(instance.id)) {
                    InstanceRow(instance: $instance)
                }
            }

            NavigationLink(value: Path.createInstance) {
                Text("Add instance")
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
