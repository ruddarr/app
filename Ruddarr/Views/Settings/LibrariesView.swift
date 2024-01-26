import SwiftUI

struct LibrariesView: View {
    var body: some View {
        List {
            Link(destination: URL(string: "https://github.com/kean/Nuke")!, label: {
                HStack {
                    Text("Nuke")
                    Text("12.3.0").foregroundStyle(.secondary)
                    Spacer()
                }
            })
            Link(destination: URL(string: "https://github.com/nonstrict-hq/CloudStorage")!, label: {
                HStack {
                    Text("CloudStorage")
                    Text("0.4.0").foregroundStyle(.secondary)
                    Spacer()
                }
            })
        }
        .accentColor(.primary)
        .navigationTitle("Third Party Libraries")
        .navigationBarTitleDisplayMode(.inline)
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
