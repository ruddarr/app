import SwiftUI
import Nuke
import Foundation

struct SettingsSystemSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance

    @State private var imageCacheSize: Int = 0
    @State private var showingEraseConfirmation: Bool = false

    var body: some View {
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
        let dataCache = try? DataCache(name: "com.ruddarr.images")
        imageCacheSize = dataCache?.totalSize ?? 0
    }

    func clearImageCache() {
        let dataCache = try? DataCache(name: "com.ruddarr.images")
        dataCache?.removeAll()
        imageCacheSize = 0
    }

    func resetAllSettings() {
        dependencies.router.reset()
        radarrInstance.switchTo(.void)
        settings.resetAll()
    }
}
