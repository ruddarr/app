import SwiftUI

#if os(iOS)
struct ContentView: View {
    @ObservedObject var state = ObservedDependencies.shared
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView(selection: selectedTab) {
            Tab(movies.label, image: movies.icon, value: movies) {
                MoviesView()
            }

            Tab(series.label, image: series.icon, value: series) {
                SeriesView()
            }

            Tab(artists.label, systemImage: artists.icon, value: artists) {
                ArtistsView()
            }

            Tab(calendar.label, systemImage: calendar.icon, value: calendar) {
                CalendarView()
            }

            Tab(activity.label, systemImage: activity.icon, value: activity) {
                ActivityView()
            }
            .badge(Queue.shared.itemsWithIssues)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.never)
        .tabViewSidebarHeader {
            Text(verbatim: Ruddarr.name)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if !isRunningIn(.preview) {
                dependencies.router.selectedTab = settings.tab
            }

            UITabBarItem.appearance().badgeColor = UIColor(settings.theme.tint)
        }
        .sheet(isPresented: $state.showSettings) {
            SettingsView()
        }
        .onBecomeActive(perform: handleScenePhaseChange)
        .displayToasts()
        .whatsNewSheet()
        .reportBugSheet()
    }

    var movies: TabItem { .movies }
    var series: TabItem { .series }
    var artists: TabItem { .artists }
    var calendar: TabItem { .calendar }
    var activity: TabItem { .activity }

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
