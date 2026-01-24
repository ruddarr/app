import SwiftUI

#if os(macOS)
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.controlActiveState) var controlActiveState

    var body: some View {
        NavigationSplitView {
            List {
                sidebarRow(movies, iconKind: .asset)
                sidebarRow(series, iconKind: .asset)

                sidebarRow(calendar, iconKind: .system)
                sidebarRow(activity, iconKind: .system, badge: Queue.shared.itemsWithIssues)

                sidebarRow(TabItem.settings, iconKind: .system)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            ZStack {
                switch selectedTabValue {
                case .movies:
                    MoviesView()
                case .series:
                    SeriesView()
                case .calendar:
                    CalendarView()
                case .activity:
                    ActivityView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        .displayToasts()
        .whatsNewSheet()
        .reportBugSheet()
        .onChange(of: controlActiveState, handleScenePhaseChange)
    }

    // TODO: instance pickers in bottom area
    // https://github.com/ruddarr/app/blob/152169429d21f4c5dbb4522b8ce1e55db7e68256/Ruddarr/Views/ContentViewMac.swift#L36-L46

    var movies: TabItem { .movies }
    var series: TabItem { .series }
    var calendar: TabItem { .calendar }
    var activity: TabItem { .activity }

    private var selectedTabValue: TabItem {
        dependencies.router.selectedTab
    }

    func handleScenePhaseChange() {
        if controlActiveState == .key {
            Telemetry.maybePing(with: settings)
            Notifications.maybeUpdateWebhooks(settings)
        }
    }

    private func selectTab(_ tab: TabItem) {
        let from = dependencies.router.selectedTab
        dependencies.router.selectedTab = tab
        handleTabChange(from, tab)
    }

    func handleTabChange(_ from: TabItem, _ to: TabItem) {
        guard from == to else { return }

        switch to {
        case .calendar: NotificationCenter.default.post(name: .scrollToToday)
        default: break
        }
    }

    private enum IconKind { case asset, system }

    @ViewBuilder
    private func sidebarRow(_ tab: TabItem, iconKind: IconKind, badge: Int? = nil) -> some View {
        Button {
            selectTab(tab)
        } label: {
            HStack(spacing: 10) {
                Label {
                    Text(tab.label)
                } icon: {
                    switch iconKind {
                    case .asset:
                        Image(tab.icon)
                    case .system:
                        Image(systemName: tab.icon)
                    }
                }

                Spacer()

                if let badge, badge > 0 {
                    Text(verbatim: "\(badge)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(settings.theme.tint, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 2, leading: 6, bottom: 2, trailing: 6))
        .background(
            selectedTabValue == tab ? Color.accentColor.opacity(0.18) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
#endif

#Preview {
    ContentView()
        .withAppState()
}
