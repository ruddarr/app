import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPortrait = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    private let orientationChangePublisher = NotificationCenter.default.publisher(
        for: UIDevice.orientationDidChangeNotification
    )

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(
                columnVisibility: $columnVisibility,
                sidebar: {
                    sidebar
                },
                detail: {
                    screen(for: dependencies.router.selectedTab)
                }
            )
            .displayToasts()
            .onAppear {
                isPortrait = UIDevice.current.orientation.isPortrait
                columnVisibility = isPortrait ? .automatic : .doubleColumn
            }
            .onReceive(orientationChangePublisher) { _ in
                handleOrientationChange()
            }
            .onChange(of: scenePhase) { new, old in
                handleScenePhaseChange(new, old)
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
                        .displayToasts()
                        .tag(tab)
                }
            }
            .onChange(of: scenePhase) { new, old in
                handleScenePhaseChange(new, old)
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

    var sidebar: some View {
        List(selection: dependencies.$router.selectedTab.optional) {
            Text("Ruddarr")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom)

            ForEach(Tab.allCases) { tab in
                let button = Button {
                    dependencies.router.selectedTab = tab

                    if isPortrait {
                        columnVisibility = .detailOnly
                    }
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
        .hideSidebarToggle(!isPortrait)
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView()
        case .shows:
            ShowsView()
        case .settings:
            SettingsView()
        }
    }

    func handleScenePhaseChange(_ new: ScenePhase, _ old: ScenePhase) {
        if new == .inactive && old == .active {
            Telemetry.shared.maybeUploadTelemetry(settings: settings)
        }
    }

    func handleOrientationChange() {
        if let windowScene = UIApplication.shared.connectedScenes.first(
            where: { $0.activationState == .foregroundActive }
        ) as? UIWindowScene {
            isPortrait = windowScene.interfaceOrientation.isPortrait
            columnVisibility = isPortrait ? .detailOnly : .doubleColumn
        }
    }
}

#Preview {
    ContentView()
        .withAppState()
}
