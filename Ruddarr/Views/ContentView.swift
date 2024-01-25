import SwiftUI

extension EnvironmentValues {
  subscript<Key: EnvironmentKey>(key _: KeyPath<Key,Key> = \Key.self) -> Key.Value {
    get { self[Key.self] }
    set { self[Key.self] = newValue }
  }
}
extension Environment where Value: EnvironmentKey, Value.Value == Value {
    init() {
        self.init(\.[key: \Value.self])
    }
}

protocol EmptyInitilizable {
    init()
}
protocol DefaultKey: EnvironmentKey, EmptyInitilizable {
}
fileprivate var singletonCache: [ObjectIdentifier: Any] = [:]

extension DefaultKey where Value == Self {
    // unfortunately this generic context doesn't support stored static properties, so we need our own external cache (to make sure defaultValue is always same instance). Not a big deal.
    static var defaultValue: Self {
        singletonCache[ObjectIdentifier(Self.self)] as? Self ?? {
            let instance = Self()
            singletonCache[ObjectIdentifier(Self.self)] = instance
            return instance
        }()
    }
}

@Observable final class TabRouter: DefaultKey {
    var selectedTab: Tab = .movies
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


struct ContentView: View {
    
    @Environment() var tabRouter: TabRouter
    @Environment() var moviesRouter: MoviesView.Router
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        @Bindable var tabRouter = tabRouter
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(selection: $tabRouter.selectedTab.optional) {
                    Text("Ruddarr")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom)

                    ForEach(Tab.allCases) { tab in
                        let button = Button {
                            tabRouter.selectedTab = tab
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
                screen(for: tabRouter.selectedTab)
            }
        } else {
            TabView(selection: $tabRouter.selectedTab.onSet {
                if $0 == tabRouter.selectedTab {
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
            moviesRouter.path = .init()
        case .settings:
            break
//            router.settingsPath = .init()
        default:
            break
        }
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView(
//                onSettingsLinkTapped: {
//                    router.selectedTab = .settings
//                }
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
