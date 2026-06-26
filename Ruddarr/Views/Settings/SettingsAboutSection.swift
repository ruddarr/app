import SwiftUI

struct SettingsAboutSection: View {
    @EnvironmentObject var settings: AppSettings

    @Environment(\.openURL) var openURL

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
            Label("Release Notes", systemImage: "sparkles.rectangle.stack")
                .labelStyle(SettingsIconLabelStyle())
        }
    }

    var share: some View {
        ShareLink(item: Links.AppShare) {
            Label("Share App", systemImage: "square.and.arrow.up")
                .labelStyle(SettingsIconLabelStyle())
        }
    }

    var review: some View {
        Link(destination: Links.AppStore.appending(queryItems: [
            .init(name: "action", value: "write-review"),
        ])) {
            Label("Leave a Review", systemImage: "star.fill")
                .labelStyle(SettingsIconLabelStyle())
        }
    }

    var macOS: some View {
        Link(destination: Links.TestFlight) {
            Label("TestFlight for macOS", systemImage: "macwindow.and.pointer.arrow")
                .labelStyle(SettingsIconLabelStyle())
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
