import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPortrait = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showTabViewOverlay: Bool = true

    @ScaledMetric(relativeTo: .body) var safeAreaInsetHeight = 48

    private let orientationChangePublisher = NotificationCenter.default.publisher(
        for: UIDevice.orientationDidChangeNotification
    )

    init() {
        UITabBar.appearance().unselectedItemTintColor = .clear
        UITabBar.appearance().tintColor = .clear // this does not work (see `.tint` below)
    }

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(
                columnVisibility: $columnVisibility,
                sidebar: {
                    sidebar
                        .ignoresSafeArea(.all, edges: .bottom)
                },
                detail: {
                    screen(for: dependencies.router.selectedTab)
                }
            )
            .displayToasts()
            .whatsNewSheet()
            .onAppear {
                isPortrait = UIDevice.current.orientation.isPortrait
                columnVisibility = isPortrait ? .automatic : .doubleColumn
            }
            .onReceive(orientationChangePublisher) { _ in
                handleOrientationChange()
            }
            .onChange(of: scenePhase, handleScenePhaseChange)
        } else {
            TabView(selection: dependencies.$router.selectedTab.onSet {
                if dependencies.router.selectedTab == $0 { goToRootOrTop(tab: $0) }
            }) {
                ForEach(Tab.allCases) { tab in
                    screen(for: tab)
                        .tint(settings.theme.tint) // restore tint for view
                        .tabItem { tab.label }
                        .displayToasts()
                        .tag(tab)
                }
            }
            .tint(.clear) // hide selected `tabItem` tint
            .overlay(alignment: .bottom) { // the default `tabItem`s are hidden, display our own
                let columns: [GridItem] = Array(repeating: .init(.flexible()), count: Tab.allCases.count)

                if showTabViewOverlay {
                    LazyVGrid(columns: columns) {
                        ForEach(Tab.allCases) { tab in
                            tab.stack
                                .foregroundStyle(
                                    dependencies.router.selectedTab == tab ? settings.theme.tint : .gray
                                )
                        }
                    }
                    .allowsHitTesting(false)
                    .padding(.horizontal, 4)
                }
            }
            .whatsNewSheet()
            .onChange(of: scenePhase, handleScenePhaseChange)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                showTabViewOverlay = false
            }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                showTabViewOverlay = true
            }
        }
    }

    var sidebar: some View {
        List(selection: dependencies.$router.selectedTab.optional) {
            Text(verbatim: "Ruddarr")
                .font(.largeTitle.bold())

            ForEach(Tab.allCases) { tab in
                if tab != .settings {
                    rowButton(for: tab)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            List(selection: dependencies.$router.selectedTab.optional) {
                ForEach(Tab.allCases) { tab in
                    if tab == .settings {
                        rowButton(for: tab)
                    }
                }
            }
            .frame(height: safeAreaInsetHeight)
            .scrollDisabled(true)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView()
        case .series:
            SeriesView()
        case .calendar:
            CalendarView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    func rowButton(for tab: Tab) -> some View {
        Button {
            if dependencies.router.selectedTab == tab {
                goToRootOrTop(tab: tab)
            } else {
                dependencies.router.selectedTab = tab
            }

            columnVisibility = isPortrait ? .automatic : .doubleColumn
        } label: {
            tab.row
        }
    }

    func handleScenePhaseChange(_ oldPhase: ScenePhase, _ phase: ScenePhase) {
        if phase == .active {
            Notifications.shared.maybeUpdateWebhooks(settings)
            Telemetry.shared.maybeUploadTelemetry(settings)
        }

        if phase == .background {
            addQuickActions()
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

    func goToRootOrTop(tab: Tab) {
        switch tab {
        case .movies:
            dependencies.router.moviesPath.isEmpty
                ? dependencies.router.moviesScoll.send()
                : (dependencies.router.moviesPath = .init())
        case .series:
            dependencies.router.seriesPath.isEmpty
                ? dependencies.router.seriesScoll.send()
                : (dependencies.router.seriesPath = .init())
        case .calendar:
            dependencies.router.calendarScoll.send()
        case .settings:
            dependencies.router.settingsPath = .init()
        }
    }

    func addQuickActions() {
        QuickActions().registerShortcutItems()
    }
}

#Preview {
    ContentView()
        .withAppState()
}
