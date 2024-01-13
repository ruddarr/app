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
            .navigationTitle("Settings")
        }
    }

    @State private var instances: [Instance] = (0..<3).map {
        Instance(label: "Instance #\($0)", url: URL(string: "https://example.com")!)
    }
    
    @State private var draftInstance = Instance(
        label: "", url: URL(string: "https://example.com")!
    )
    
    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach(instances) { instance in
                NavigationLink {
                    InstanceForm(
                        instance: $instances[instances.firstIndex(of: instance)!]
                    )
                } label: {
                    VStack(alignment: .leading) {
                        Text(instance.label)
                        Text(instance.url.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                }
            }
            NavigationLink("Add instance") {
                InstanceForm(instance: $draftInstance)
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

struct InstanceForm: View {
    @Binding var instance: Instance
    
    var body: some View {
        Form {
            Section {
                List {
                    HStack {
                        Text("Label")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("Synology", text: $instance.label)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Host")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("https://10.0.1.5:7878", value: $instance.url, format: .url)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("API Key")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.label)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
            }

            Section {
                Button("Delete Instance") {
                    //
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.red)
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    //
                }
            }
        }
    }
}

#Preview {
    ContentView(selectedTab: .settings)
        .withSelectedColorScheme()
}
