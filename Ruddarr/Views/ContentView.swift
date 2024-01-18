import SwiftUI

struct ContentView: View {
    @State var selectedTab: Tab = .movies
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(selection: $selectedTab.optional) {
                    Text("Ruddarr")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom)

                    ForEach(Tab.allCases) { tab in
                        let button = Button {
                            selectedTab = tab
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
                screen(for: selectedTab)
            }
        } else {
            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    screen(for: tab)
                        .tabItem { tab.label }
                        .tag(tab)
                }
            }
        }
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch selectedTab {
        case .movies: MoviesView(onSettingsLinkTapped: { selectedTab = .settings })
        case .shows: ShowsView()
        case .settings: SettingsView()
        }
    }
}

enum Tab: Hashable, CaseIterable, Identifiable {
    var id: Self { self }

    case movies
    case shows
    case settings

    @ViewBuilder
    var label: some View {
        switch self {
        case .movies:
            Label("Movies", systemImage: "popcorn.fill")
        case .shows:
            Label("Shows", systemImage: "tv.inset.filled")
        case .settings:
            Label("Settings", systemImage: "gear")
        }
    }
}

#Preview {
    ContentView()
}
