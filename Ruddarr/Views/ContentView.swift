
import SwiftUI

struct ContentView: View {
    @State var selectedTab: Tab = .movies
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Group {
                    switch tab {
                    case .movies: MoviesView()
                    case .shows: ShowsView()
                    case .settings: SettingsView()
                    }
                }
                .tabItem { tab.label }
                .tag(tab)
            }
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
