import SwiftUI
import CoreSpotlight
import Nuke

struct SettingsSystemSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    @State private var imageCacheSize: Int = 0
    @State private var showingEraseConfirmation: Bool = false

    var body: some View {
        Section {
            LabeledContent {
                Text(formatBytes(imageCacheSize))
            } label: {
                Button("Clear Image Cache", role: .destructive) {
                    clearImageCache()
                }
                #if os(macOS)
                    .buttonStyle(.link).foregroundStyle(.red)
                #endif
            }.onAppear {
                calculateImageCacheSize()
            }

            Button(role: .destructive, action: {
                deleteSpotlightIndexes()
            }, label: {
                Text("Delete Spotlight Index")
            })
            #if os(macOS)
                .buttonStyle(.link).foregroundStyle(.red)
            #endif

            Button("Reset All Settings", role: .destructive) {
                showingEraseConfirmation = true
            }
            #if os(macOS)
                .buttonStyle(.link).foregroundStyle(.red)
            #endif
            .alert(
                "Are you sure you want to erase all settings?",
                isPresented: $showingEraseConfirmation
            ) {
                Button("Reset All Settings", role: .destructive) {
                    resetAllSettings()
                }
                Button("Cancel", role: .cancel) { }
            }
            .tint(nil)
        } header: {
            Text("System", comment: "Preferences section header")
        } footer: {
            if let version = buildVersion {
                HStack {
                    Spacer()
                    Text(version).font(.footnote)
                    Spacer()
                }
                .padding(.vertical)
            }
        }
    }

    var buildVersion: String? {
        guard let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String else {
            return nil
        }

        guard let buildNumber = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String else {
            return nil
        }

        return String(localized: "Version \(appVersion) (\(buildNumber))", comment: "$1 = version, $2 = build")
    }

    func calculateImageCacheSize() {
        let dataCache = try? DataCache(name: "com.ruddarr.images")
        imageCacheSize = dataCache?.totalSize ?? 0
    }

    func clearImageCache() {
        let dataCache = try? DataCache(name: "com.ruddarr.images")
        dataCache?.removeAll()

        withAnimation(.interactiveSpring) {
            imageCacheSize = 0
        }
    }

    func deleteSpotlightIndexes() {
        for instance in settings.instances {
            Task {
                await Spotlight(instance.id).deleteInstanceIndex()
            }
        }

        Task {
            // delete dangling items as well
            try? await CSSearchableIndex.default().deleteAllSearchableItems()
        }
    }

    func resetAllSettings() {
        dependencies.router.reset()
        radarrInstance.switchTo(.radarrVoid)
        sonarrInstance.switchTo(.sonarrVoid)
        settings.resetAll()
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
