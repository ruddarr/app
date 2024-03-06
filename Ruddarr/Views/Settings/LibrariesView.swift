import SwiftUI

struct LibrariesView: View {
    var body: some View {
        List {
            LibrariesViewItem(
                url: "https://github.com/kean/Nuke",
                name: "Nuke",
                version: "12.4.0"
            )

            LibrariesViewItem(
                url: "https://github.com/nonstrict-hq/CloudStorage",
                name: "CloudStorage",
                version: "0.4.0"
            )

            LibrariesViewItem(
                url: "https://github.com/getsentry/sentry-cocoa",
                name: "Sentry",
                version: "8.21.0"
            )

            LibrariesViewItem(
                url: "https://github.com/TelemetryDeck/SwiftClient",
                name: "TelemetryDeck",
                version: "1.5.1"
            )
        }
        .navigationTitle("Third Party Libraries")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
    }
}

struct LibrariesViewItem: View {
    var url: String
    var name: String
    var version: String

    var body: some View {
        Link(destination: URL(string: url)!, label: {
            HStack {
                Text(name)
                Text(version).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
        })
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.libraries
    )

    return ContentView()
        .withAppState()
}
