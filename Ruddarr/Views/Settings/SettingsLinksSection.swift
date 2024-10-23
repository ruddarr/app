import SwiftUI

struct SettingsLinksSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Section(header: Text("Community")) {
            discord
            beta
            contribute
            translate
        }

        Section(header: Text("Apps")) {
            appLink(
                "Sable",
                URL(string: "https://apps.apple.com/app/sable/id6630387095")!
            )

            appLink(
                "DSLoad",
                URL(string: "https://apps.apple.com/app/dsload-station/id1510628586")!
            )
        }
    }

    var discord: some View {
        Link(destination: Links.Discord) {
            Label {
                Text("Join the Discord").tint(.primary)
            } icon: {
                Image(systemName: "text.bubble")
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    var beta: some View {
        Link(destination: Links.TestFlight) {
            Label {
                Text("Test the Beta").tint(.primary)
            } icon: {
                Image(systemName: "testtube.2")
                    .foregroundStyle(settings.theme.tint)
                    .scaleEffect(0.9)
            }
        }
    }

    var contribute: some View {
        Link(destination: Links.GitHub, label: {
            Label {
                Text("Contribute on GitHub").tint(.primary)
            } icon: {
                Image(systemName: "curlybraces.square")
                    .foregroundStyle(settings.theme.tint)
            }
        })
    }

    var translate: some View {
        Link(destination: Links.Crowdin, label: {
            Label {
                Text("Translate the App").tint(.primary)
            } icon: {
                Image(systemName: "character.bubble")
                    .foregroundStyle(settings.theme.tint)
            }
        })
    }

    func appLink(_ name: String, _ url: URL) -> some View {
        Link(
            destination: url,
            label: {
                Label {
                    Text(verbatim: name)
                        .tint(.primary)
                } icon: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(settings.theme.tint)
                }
            }
        )
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
