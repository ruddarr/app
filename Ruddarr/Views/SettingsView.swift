import SwiftUI

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        NavigationStack {
            List {
                instanceSection
                settingsSection
                aboutSection
            }
            .animation(.easeInOut, value: instances)
            .navigationTitle("Settings")
        }
    }

    @AppStorage("instances") private var instances: [Instance] = []
    
    private var draftInstance: Instance {
        Instance()
    }
    
    var instanceSection: some View {
        Group {
            Section(header: Text("Instances")) {
                ForEach(instances) { instance in
                    NavigationLink {
                        InstanceForm(
                            state: .update,
                            instance: instance,
                            saveInstance: { ins in
                                updateInstance(ins)
                            },
                            deleteInstance: { ins in
                                deleteInstance(ins)
                            }
                        )
                    } label: {
                        VStack(alignment: .leading) {
                            Text(instance.label)
                            Text(instance.urlString)
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                NavigationLink("Add instance") {
                    InstanceForm(
                        state: .create,
                        instance: draftInstance,
                        saveInstance: { ins in
                            saveInstance(ins)
                        }
                    )
                }
            }
            
            if !instances.isEmpty {
                deleteAllInstanceView
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
    
    // TODO: Add button to delete all `@AppStorage` and reset the app
    
    var deleteAllInstanceView: some View {
        Section {
            Button("Delete All Instances") {
                deleteAllInstances()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.red)
        }
    }
}

extension SettingsView {
    func saveInstance(_ instance: Instance) {
        instances.append(instance)
    }
    
    func updateInstance(_ instance: Instance) {
        guard let instanceForUpdation = instances.enumerated().first(where: { $0.element.id == instance.id }) else { return }
        instances.remove(at: instanceForUpdation.offset)
        instances.insert(instance, at: instanceForUpdation.offset)
    }
    
    func deleteInstance(_ instance: Instance) {
        instances.removeAll(where: { $0.id == instance.id })
    }
    
    func deleteAllInstances() {
        withAnimation {
            instances.removeAll()
        }
    }
}
