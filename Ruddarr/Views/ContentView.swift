import SwiftUI

#if os(iOS)
struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        if #available(iOS 27.0, *), deviceType == .phone {
            GeometryReader { geometry in
                content.defaultTabBarPlacement(
                    geometry.size.width > geometry.size.height ? .sidebar : .tabBar
                )
            }
        } else {
            content
        }
    }

    var content: some View {
        TabView(selection: selectedTab) {
            Tab(movies.label, image: movies.icon, value: movies) {
                MoviesView()
                    .displayToasts()
            }

            Tab(series.label, image: series.icon, value: series) {
                SeriesView()
                    .displayToasts()
            }

            Tab(calendar.label, systemImage: calendar.icon, value: calendar) {
                CalendarView()
                    .displayToasts()
            }

            Tab(activity.label, systemImage: activity.icon, value: activity) {
                ActivityView()
                    .displayToasts()
            }
            .badge(Queue.shared.itemsWithIssues)

            if deviceType == .pad {
                Tab(history.label, systemImage: history.icon, value: history) {
                    HistoryView()
                        .displayToasts()
                }
                .defaultVisibility(.hidden, for: .tabBar)
            }

            Tab(TabItem.settings.label, systemImage: TabItem.settings.icon, value: TabItem.settings) {
                SettingsView()
                    .displayToasts()
            }
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader {
            SidebarTitle(title: Ruddarr.name)
                .frame(height: 0)
        }
        .tabBarMinimizeBehavior(.never)
        .onAppear {
            UITabBarItem.appearance().badgeColor = UIColor(settings.theme.tint)
        }
        .task {
            await updateTelemetryAndWebhooks()
        }
        .onBecomeActive(perform: updateTelemetryAndWebhooks)
        .whatsNewSheet()
        .reportBugSheet()
        // .testFlightNotice()
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

    func updateTelemetryAndWebhooks() async {
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

private struct SidebarTitle: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> TitleView {
        let view = TitleView()
        view.title = title
        return view
    }

    func updateUIView(_ view: TitleView, context: Context) {}

    final class TitleView: UIView {
        var title = ""

        override func didMoveToWindow() {
            super.didMoveToWindow()

            for view in sequence(first: self as UIView, next: \.superview) {
                guard let bar = view.subviews.lazy.compactMap({ $0 as? UINavigationBar }).first else {
                    continue
                }

                bar.topItem?.title = title
                bar.topItem?.largeTitleDisplayMode = .inline
                bar.prefersLargeTitles = true

                for case let scrollView as UIScrollView in view.subviews {
                    scrollView.topEdgeEffect.isHidden = true
                }

                return
            }
        }
    }
}
#endif

#Preview {
    ContentView()
        .withAppState()
}
