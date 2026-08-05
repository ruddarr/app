import SwiftUI

#if os(iOS)
struct ContentView: View {
    @State private var tabCustomization = TabViewCustomization()

    @Environment(AppSettings.self) private var settings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        TabView(selection: selectedTab) {
            Tab(movies.label, image: movies.icon, value: movies) {
                MoviesView()
            }

            Tab(series.label, image: series.icon, value: series) {
                SeriesView()
            }

            Tab(calendar.label, systemImage: calendar.icon, value: calendar) {
                CalendarView()
            }

            Tab(activity.label, systemImage: activity.icon, value: activity) {
                ActivityView()
            }
            .badge(Queue.shared.itemsWithIssues)

            if deviceType == .pad {
                Tab(history.label, systemImage: history.icon, value: history) {
                    HistoryView()
                }
                .customizationID("tab.history")
                .defaultVisibility(.hidden, for: .tabBar)
                // .customizationBehavior(.disabled, for: .tabBar, .sidebar)
            }

            Tab(TabItem.settings.label, systemImage: TabItem.settings.icon, value: TabItem.settings) {
                SettingsView()
            }
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabCustomization)
        .tabBarMinimizeBehavior(.never)
        .onAppear {
            if !isRunningIn(.preview) {
                dependencies.router.selectedTab = settings.tab
            }

            UITabBarItem.appearance().badgeColor = UIColor(settings.theme.tint)
        }
        .onBecomeActive(perform: handleScenePhaseChange)
        .displayToasts()
        .whatsNewSheet()
        .reportBugSheet()
        .instanceWebSheet()
    }

    var movies: TabItem { .movies }
    var series: TabItem { .series }
    var calendar: TabItem { .calendar }
    var activity: TabItem { .activity }
    var history: TabItem { .history }

    var selectedTab: Binding<TabItem> {
        Binding<TabItem>(
            get: {
                dependencies.router.selectedTab
            },
            set: {
                let from = dependencies.router.selectedTab
                dependencies.router.selectedTab = $0
                handleTabChange(from, $0)
            }
        )
    }

    func handleScenePhaseChange() async {
        Telemetry.maybePing(with: settings)
        Notifications.maybeUpdateWebhooks(settings)
    }

    func handleTabChange(_ from: TabItem, _ to: TabItem) {
        guard from == to else { return }

        switch to {
        case .calendar: NotificationCenter.default.post(name: .scrollToToday)
        default: break
        }
    }
}
#endif

#Preview {
    ContentView()
        .withAppState()
}
