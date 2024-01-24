import SwiftUI
import Nuke

struct SettingsView: View {
    @AppStorage("instances") private var instances: [Instance] = []

    enum Path: Hashable {
        case libraries
        case createInstance
        case editInstance(Instance.ID)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.settingsPath) {
            List {
                instanceSection
                aboutSection
                systemSection
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .libraries:
                    ThridPartyLibraries()
                case .createInstance:
                    InstanceForm(state: .create, instance: Instance())
                    // InstanceForm(state: .create, instance: Instance(url: "HTTP://10.0.1.5:8310/api", apiKey: "8f45bce99e254f888b7a2ba122468dbe"))
                case .editInstance(let instanceId):
                    let instance = instances.first(where: { $0.id == instanceId })
                    InstanceForm(state: .update, instance: instance!)
                }
            }
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach(instances) { instance in
                NavigationLink(value: Path.editInstance(instance.id)) {
                    VStack(alignment: .leading) {
                        Text(instance.label)
                        Text(instance.type.rawValue).font(.footnote).foregroundStyle(.gray)
                    }
                }
            }
            NavigationLink(value: Path.createInstance) {
                Text("Add instance")
            }
        }
    }

    let shareUrl = URL(string: "https://ruddarr.com")!
    let githubUrl = URL(string: "https://github.com/tillkruss/ruddarr/")!
    let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/id663592361")!

    var aboutSection: some View {
        Section(header: Text("About")) {
            ShareLink(item: shareUrl) {
                Label("Share App", systemImage: "square.and.arrow.up")
            }

            Link(destination: reviewUrl, label: {
                Label("Leave a Review", systemImage: "star")
            })

            Link(destination: supportEmailUrl(), label: {
                Label("Email Support", systemImage: "square.and.pencil")
            })

            Link(destination: githubUrl, label: {
                Label("Contribute on GitHub", systemImage: "chevron.left.slash.chevron.right")
            })

            NavigationLink { ThridPartyLibraries() } label: {
                Label("Third Party Libraries", systemImage: "building.columns")
            }
        }
        .accentColor(.primary)
    }

    @State private var imageCacheSize: Int = 0
    @State private var showingEraseConfirmation: Bool = false

    var systemSection: some View {
        Section(header: Text("System")) {
            Button(role: .destructive, action: {
                clearImageCache()
            }, label: {
                LabeledContent(
                    "Clear Image Cache",
                    value: ByteCountFormatter().string(fromByteCount: Int64(imageCacheSize))
                )
            }).onAppear {
                calculateImageCacheSize()
            }

            Button("Erase All Settings", role: .destructive) {
                showingEraseConfirmation = true
            }
            .confirmationDialog("Are you sure?", isPresented: $showingEraseConfirmation) {
                Button("Erase All Settings", role: .destructive) {
                    if let bundleID = Bundle.main.bundleIdentifier {
                        instances.removeAll()
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                        showingEraseConfirmation = false
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to erase all settings?")
            }
        }
        .accentColor(.primary)
    }

    func calculateImageCacheSize() {
        let dataCache = try? DataCache(name: "com.github.radarr.DataCache")
        imageCacheSize = dataCache?.totalSize ?? 0
    }

    func clearImageCache() {
        let dataCache = try? DataCache(name: "com.github.radarr.DataCache")
        dataCache?.removeAll()
        imageCacheSize = 0
    }

    func supportEmailUrl() -> URL {
        let address = "support@ruddarr.com"
        let subject = "Support Request"

        let body = """
        ---
        The following information may help with debugging:

        App Version:
        iOS Version:
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            if UIApplication.shared.canOpenURL(url) {
                return url
            }
        }

        return URL(string: "https://github.com/tillkruss/ruddarr/issues/")!
    }
}

struct ThridPartyLibraries: View {
    var body: some View {
        List {
            Link(destination: URL(string: "https://github.com/kean/Nuke")!, label: {
                HStack {
                    Text("Nuke")
                    Text("12.3.0").foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            })
        }
        .accentColor(.primary)
        .navigationTitle("Third Party Libraries")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
}

#Preview("Libraries") {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.libraries
    )

    return ContentView()
}
