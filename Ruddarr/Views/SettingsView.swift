import SwiftUI

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("instances") private var instances: [Instance] = []

    var body: some View {
        NavigationStack {
            List {
                instanceSection
                settingsSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach(instances) { instance in
                NavigationLink {
                    InstanceForm(state: .update, instance: instance)
                } label: {
                    VStack(alignment: .leading) {
                        Text(instance.label)
                        Text(instance.type.rawValue).font(.footnote).foregroundStyle(.gray)
                    }
                }
            }
            NavigationLink("Add instance") {
                InstanceForm(state: .create, instance: Instance())
            }
        }
    }

    var settingsSection: some View {
        Section(header: Text("Preferences")) {
            HStack {
                Toggle(isOn: $darkMode) {
                    Label("Dark Mode", systemImage: "moon")
                }
            }
        }
        .accentColor(.primary)
        .listRowSeparatorTint(.blue)
        .listRowSeparator(.hidden)
    }

    var aboutSection: some View {
        Section {
            NavigationLink { ContentView() } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        .accentColor(.primary)
        .listRowSeparatorTint(.blue)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    ContentView(selectedTab: .settings)
        .withSelectedColorScheme()
}
