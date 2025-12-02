import SwiftUI

struct SettingsAboutSection: View {
    @EnvironmentObject var settings: AppSettings

    @Environment(\.openURL) var openURL

    var body: some View {
        Section {
            share
            review
            discord
            contribute
            translate
        } header: {
            Text("About", comment: "Preferences section title")
        }
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
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

    var discord: some View {
        Link(destination: Links.Discord) {
            Label("Join the Discord", systemImage: "text.bubble")
                .labelStyle(SettingsIconLabelStyle())
        }
    }

    var contribute: some View {
        Link(destination: Links.GitHubIssues, label: {
            Label("Report an Issue", systemImage: "exclamationmark.bubble")
                .labelStyle(SettingsIconLabelStyle())
        })
    }

    var translate: some View {
        Link(destination: Links.Crowdin, label: {
            Label("Translate the App", systemImage: "globe.europe.africa")
                .labelStyle(SettingsIconLabelStyle())
        })
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
