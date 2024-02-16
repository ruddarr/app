import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

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

                case .libraries:
                    LibrariesView()

                case .createInstance:
                    InstanceEditView(mode: .create, instance: Instance())

                case .viewInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceView(instance: instance)
                    }

                case .editInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceEditView(mode: .update, instance: instance)
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
