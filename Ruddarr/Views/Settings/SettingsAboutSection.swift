import SwiftUI

struct SettingsAboutSection: View {
    @EnvironmentObject var settings: AppSettings

    @Environment(\.openURL) var openURL
    @Environment(\.presentBugSheet) var presentBugSheet

    var body: some View {
        Section {
            share
            review
            discord
            bug
            contribute
            translate
        } header: {
            Text("About", comment: "Preferences section title")
        }
    }

    var share: some View {
        ShareLink(item: Links.AppShare) {
            Label("Share App", systemImage: "square.and.arrow.up")
                .labelStyle(SettingsIconLabelStyle(color: .blue))
        }
        #if os(macOS)
            .buttonStyle(.link)
        #endif
    }

    var review: some View {
        Link(destination: Links.AppStore.appending(queryItems: [
            .init(name: "action", value: "write-review"),
        ])) {
            Label("Leave a Review", systemImage: "star.fill")
                .labelStyle(SettingsIconLabelStyle(color: .orange, size: 13))
        }
    }

    var discord: some View {
        Link(destination: Links.Discord) {
            Label("Join the Discord", systemImage: "ellipsis.bubble")
                .labelStyle(SettingsIconLabelStyle(color: .systemPurple, size: 13))
        }
    }

    var bug: some View {
        Button {
            presentBugSheet.wrappedValue = true
        } label: {
            Label("Report a Bug", systemImage: "exclamationmark.bubble")
                .labelStyle(SettingsIconLabelStyle(color: .systemPurple, size: 13))
        }
        #if os(macOS)
            .buttonStyle(.link)
        #endif
    }

    var contribute: some View {
        Link(destination: Links.GitHub, label: {
            Label("Contribute on GitHub", systemImage: "curlybraces")
                .labelStyle(SettingsIconLabelStyle(color: .gray, size: 12))
        })
    }

    var translate: some View {
        Link(destination: Links.Crowdin, label: {
            Label("Translate the App", systemImage: "globe.europe.africa")
                .labelStyle(SettingsIconLabelStyle(color: .gray))
        })
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
