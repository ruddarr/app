import SwiftUI

struct SettingsAboutSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            share
            review
            releases
            macOS
        } header: {
            Text("About", comment: "Preferences section title")
        }
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
    }

    var releases: some View {
        NavigationLink(value: SettingsView.Path.changelog) {

            Label {
                Text("Release Notes")
            } icon: {
                Image(systemName: "sparkles.rectangle.stack")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(settings.theme.tint, .primary)
            }
            .labelStyle(.settingsIcon)
        }
    }

    var share: some View {
        ShareLink(item: Links.AppShare) {
            Label("Share App", systemImage: "square.and.arrow.up")
                .labelStyle(.settingsIcon)
        }
    }

    var review: some View {
        Link(destination: Links.AppStore.appending(queryItems: [
            .init(name: "action", value: "write-review"),
        ])) {
            Label("Leave a Review", systemImage: "star.fill")
                .labelStyle(.settingsIcon)
        }
    }

    var macOS: some View {
        Link(destination: Links.TestFlight) {
            Label("TestFlight for macOS", systemImage: "macwindow.and.pointer.arrow")
                .labelStyle(.settingsIcon)
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
