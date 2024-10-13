import SwiftUI

struct SettingsLinksSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Section(header: Text("Community")) {
            discord
            beta
            contribute
            sable
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
    
    var sable: some View {
        Link(destination: Links.Sable, label: {
            Label {
                Text("Check out Sable").tint(.primary)
            } icon: {
                Image(systemName: "arrowshape.down")
                    .foregroundStyle(settings.theme.tint)
            }
        })
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
