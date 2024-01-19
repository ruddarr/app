import SwiftUI
import Nuke

struct SettingsView: View {
    @AppStorage("instances") private var instances: [Instance] = []

    var body: some View {
        NavigationStack {
            List {
                instanceSection
                aboutSection
                systemSection
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

    var systemSection: some View {
        Section(header: Text("System")) {
            Button(role: .destructive, action: {
                clearImageCache()
            }, label: {
                LabeledContent("Clear Image Cache", value: imageCacheSize())
            })

            Button(role: .destructive, action: {
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }
            }, label: {
                Text("Erase All Settings")
            })
        }
        .accentColor(.primary)
        .listRowSeparatorTint(.blue)
        .listRowSeparator(.hidden)
    }

    func imageCacheSize() -> String {
        let name = "com.github.radarr.DataCache"
        let dataCache = try? DataCache(name: name)
        let size = dataCache?.totalSize

        return ByteCountFormatter().string(fromByteCount: Int64(size!))
    }

    func clearImageCache() {
        let name = "com.github.radarr.DataCache"
        let dataCache = try? DataCache(name: name)

        dataCache?.removeAll()
    }
}

#Preview {
    ContentView(selectedTab: .settings)
}
