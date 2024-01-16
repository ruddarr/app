
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
                        if tab.id == .settings {
                            Spacer()
                        }

                        Button {
                            selectedTab = tab
                            columnVisibility = .detailOnly
                        } label: {
                            tab.label
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
        case .movies: MoviesView()
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

struct ColorSchemeViewModifier: ViewModifier {
    @AppStorage("darkMode") private var darkMode = false
    
    func body(content: Content) -> some View {
        content.preferredColorScheme(darkMode ? .dark : .light)
    }
}

extension View {
    func withSelectedColorScheme() -> some View {
        modifier(ColorSchemeViewModifier())
    }
}

#Preview {
    ContentView()
        .withSelectedColorScheme()
}
