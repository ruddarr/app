import SwiftUI

struct SettingsContributeSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            discord
            translate
            contribute
            reportIssues
        } header: {
            Text("Contribute", comment: "Preferences section title")
        }
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
    }

    var discord: some View {
        Link(destination: Links.Discord) {
            Label("Join the Discord", systemImage: "text.bubble")
                .labelStyle(.settingsIcon)
        }
    }

    var translate: some View {
        Link(destination: Links.Crowdin, label: {
            Label("Translate the App", systemImage: "globe.europe.africa")
                .labelStyle(.settingsIcon)
        })
    }

    var contribute: some View {
        Link(destination: Links.GitHub, label: {
            Label("Contribute on GitHub", systemImage: "curlybraces")
                .labelStyle(.settingsIcon(iconScale: 0.85))
        })
    }

    var reportIssues: some View {
        Link(destination: Links.GitHubIssues, label: {
            Label("Report an Issue", systemImage: "exclamationmark.bubble")
                .labelStyle(.settingsIcon)
        })
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
