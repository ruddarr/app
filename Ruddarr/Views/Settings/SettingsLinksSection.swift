import SwiftUI

struct SettingsLinksSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Section(header: Text("Integrations")) {
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

    func appLink(_ name: String, _ url: URL) -> some View {
        Link(
            destination: url,
            label: {
                Label(name, systemImage: "arrow.up.right")
                    .labelStyle(SettingsIconLabelStyle(color: .gray, size: 13))
            }
        )
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
