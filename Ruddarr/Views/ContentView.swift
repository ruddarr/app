import SwiftUI

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(selection: dependencies.$router.selectedTab.optional) {
                    Text("Ruddarr")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom)

                    ForEach(Tab.allCases) { tab in
                        let button = Button {
                            dependencies.router.selectedTab = tab
                            columnVisibility = .detailOnly
                        } label: {
                            tab.label
                        }

                        if case .settings = tab {
                            Section {
                                button
                            }
                        } else {
                            button
                        }
                    }
                }
            } detail: {
                screen(for: dependencies.router.selectedTab)
            }
        } else {
            TabView(selection: dependencies.$router.selectedTab.onSet {
                if $0 == dependencies.router.selectedTab {
                    pop(tab: $0)
                }
            }) {
                ForEach(Tab.allCases) { tab in
                    screen(for: tab)
                        .tabItem { tab.label }
                        .tag(tab)
                }
            }
        }
    }

    func pop(tab: Tab) {
        switch tab {
        case .movies:
            dependencies.router.moviesPath = .init()
        case .settings:
            dependencies.router.settingsPath = .init()
        default:
            break
        }
    }
    
    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView(
                onSettingsLinkTapped: {
                    dependencies.router.selectedTab = .settings
                }
            )
        case .shows:
            ShowsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
