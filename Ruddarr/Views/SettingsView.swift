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

    // TODO: convert to `@AppStorage` (default empty list)
    @State private var instances: [Instance] = (0..<3).map {
        Instance(label: "Instance #\($0)", url: URL(string: "https://example.com")!)
    }
    
    // TODO: don't default to `example.com` the fields should all be empty
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

// TODO: only save instance when user clicks on "Done" and the validation passes
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

            // TODO: only show when viewing an instance that was already saved (not a new one)
            Section {
                Button("Delete Instance") {
                    // TODO: delete instance from `@AppStorage`
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.red)
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    // TODO: validate that `URL` field can be reached via HTTP (status code 200?)
                    // TODO: save instance to `@AppStorage` (or update edited instance)
                }
            }
        }
    }
}

#Preview {
    ContentView(selectedTab: .settings)
        .withSelectedColorScheme()
}
