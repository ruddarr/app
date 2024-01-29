import os
import SwiftUI
import Nuke

struct SettingsView: View {
    private let log: Logger = logger("settings")

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance

    enum Path: Hashable {
        case libraries
        case createInstance
        case editInstance(Instance.ID)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.settingsPath) {
            List {
                instanceSection
                preferencesSection
                aboutSection
                systemSection
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .libraries:
                    LibrariesView()
                case .createInstance:
                    let instance = Instance()
                    // let instance = Instance(url: "HTTP://10.0.1.5:8310/api", apiKey: "8f45bce99e254f888b7a2ba122468dbe")
                    InstanceView(mode: .create, instance: instance)
                case .editInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceView(mode: .update, instance: instance)
                    }
                }
            }
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach(settings.instances) { instance in
                NavigationLink(value: Path.editInstance(instance.id)) {
                    InstanceRow(instance: instance)
                }
            }

            NavigationLink(value: Path.createInstance) {
                Text("Add instance")
            }
        }
    }

    var preferencesSection: some View {
        Section(header: Text("Preferences")) {
            Picker("Theme", selection: $settings.theme) {
                ForEach(Theme.allCases) { theme in
                    Text(theme.rawValue.uppercased())
                }
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

            Button {
                Task { await openSupportEmail() }
            } label: {
                Label("Email Support", systemImage: "square.and.pencil")
            }

            Link(destination: githubUrl, label: {
                Label("Contribute on GitHub", systemImage: "curlybraces.square")
            })

            NavigationLink { LibrariesView() } label: {
                Label("Third Party Libraries", systemImage: "building.columns")
            }
        }
    }

    @State private var imageCacheSize: Int = 0
    @State private var showingEraseConfirmation: Bool = false

    var systemSection: some View {
        Section(header: Text("System")) {
            Button(role: .destructive, action: {
                withAnimation { clearImageCache() }
            }, label: {
                LabeledContent(
                    "Clear Image Cache",
                    value: ByteCountFormatter().string(fromByteCount: Int64(imageCacheSize))
                )
            }).onAppear {
                calculateImageCacheSize()
            }

            Button("Reset All Settings", role: .destructive) {
                showingEraseConfirmation = true
            }
            .confirmationDialog("Are you sure?", isPresented: $showingEraseConfirmation) {
                Button("Reset All Settings", role: .destructive) {
                    resetAllSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to erase all settings?")
            }
        }
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

    func resetAllSettings() {
        radarrInstance.switchTo(.void)
        settings.resetAll()
    }

    // If desired add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`
    func openSupportEmail() async {
        let meta = await Telemetry.shared.metadata()

        let address = "support@ruddarr.com"
        let subject = "Support Request"

        let body = """
        ---
        The following information will help with debugging:

        Version: \(meta[.appVersion] ?? "nil") (\(meta[.appBuild] ?? "nil"))
        Platform: \(meta[.systemName] ?? "nil") (\(meta[.systemVersion] ?? "nil"))
        Device: \(meta[.deviceId] ?? "nil")
        User: \(meta[.cloudkitStatus]!) (\(meta[.cloudkitUserId] ?? "nil"))
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let mailtoUrl = components.url {
            if UIApplication.shared.canOpenURL(mailtoUrl) {
                if await UIApplication.shared.open(mailtoUrl) {
                    return
                }
            }

            log.warning("Unable to open mailto URL: \(mailtoUrl)")
        }

        let gitHubUrl = URL(string: "https://github.com/tillkruss/ruddarr/issues/")!

        if await UIApplication.shared.open(gitHubUrl) {
            return
        }

        log.critical("Unable to open URL: \(gitHubUrl, privacy: .public)")
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
