import SwiftUI

struct SettingsAboutSection: View {
    @State private var showBugSheet: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.openURL) var openURL

    var body: some View {
        Section(header: Text("About")) {
            share
            review
            discord
            bug
            contribute
            translate
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
                .labelStyle(SettingsIconLabelStyle(color: .orange))
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
            showBugSheet = true
        } label: {
            Label("Report a Bug", systemImage: "at")
                .labelStyle(SettingsIconLabelStyle(color: .systemPurple, size: 13))
        }
        #if os(macOS)
            .buttonStyle(.link)
        #endif
        .sheet(isPresented: $showBugSheet) {
            BugSheet().presentationDetents([.medium])
        }
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
