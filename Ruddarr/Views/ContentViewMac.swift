import SwiftUI

#if os(macOS)
struct ContentView: View {
    @Environment(AppSettings.self) var settings

    var body: some View {
        NavigationSplitView {
            List {
                sidebarItem(movies)
                sidebarItem(series)
                sidebarItem(calendar)

                sidebarItem(activity, badge: Queue.shared.itemsWithIssues)
                sidebarItem(history)

                sidebarItem(TabItem.settings)
                    .keyboardShortcut(",", modifiers: .command)

                instancesSection
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            ZStack {
                switch dependencies.router.selectedTab {
                case .movies:
                    MoviesView()
                case .series:
                    SeriesView()
                case .calendar:
                    CalendarView()
                        .frame(maxWidth: 700)
                case .activity:
                    ActivityView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        .displayToasts()
        .whatsNewSheet()
        .reportBugSheet()
        .onBecomeActive(perform: handleScenePhaseChange)
    }

    var movies: TabItem { .movies }
    var series: TabItem { .series }
    var calendar: TabItem { .calendar }
    var activity: TabItem { .activity }
    var history: TabItem { .history }

    func handleScenePhaseChange() {
        Telemetry.maybePing(with: settings)
        Notifications.maybeUpdateWebhooks(settings)
    }

    func handleTabChange(_ from: TabItem, _ to: TabItem) {
        guard from == to else { return }

        switch to {
        case .movies: dependencies.router.moviesPath = .init()
        case .series: dependencies.router.seriesPath = .init()
        case .calendar: NotificationCenter.default.post(name: .scrollToToday)
        default: break
        }
    }

    @ViewBuilder
    func sidebarItem(_ tab: TabItem, badge: Int? = nil) -> some View {
        Button {
            let from = dependencies.router.selectedTab
            dependencies.router.selectedTab = tab
            handleTabChange(from, tab)
        } label: {
            Label {
                Text(tab.label)
            } icon: {
                tab.image
                    .imageScale(.large)
                    .frame(width: 22, height: 22, alignment: .center)
            }
            .labelIconToTitleSpacing(8)
            .badge(badge == nil ? nil : renderBadge(badge))
            .padding(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 0, leading: -5, bottom: 0, trailing: -5))
        .background(
            dependencies.router.selectedTab == tab ? settings.theme.tint : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    func renderBadge(_ count: Int? = nil) -> Text? {
        guard let count, count > 0 else { return nil }
        return Text(verbatim: "\(count)")
    }

    @ViewBuilder
    var instancesSection: some View {
        @Bindable var settings = settings

        if dependencies.router.selectedTab == .movies, settings.radarrInstances.count > 1 {
            Section("Instances") {
                instanceRow(
                    instances: settings.radarrInstances,
                    selection: $settings.radarrInstanceId,
                    switchTo: { instance in
                        settings.radarrInstanceId = instance
                        dependencies.router.moviesPath = .init()
                        dependencies.router.switchToRadarrInstance = instance.uuidString
                    }
                )
            }
        }

        if dependencies.router.selectedTab == .series, settings.sonarrInstances.count > 1 {
            Section("Instances") {
                instanceRow(
                    instances: settings.sonarrInstances,
                    selection: $settings.sonarrInstanceId,
                    switchTo: { instance in
                        settings.sonarrInstanceId = instance
                        dependencies.router.seriesPath = .init()
                        dependencies.router.switchToSonarrInstance = instance.uuidString
                    }
                )
            }
        }
    }

    @ViewBuilder
    func instanceRow(
        instances: [Instance],
        selection: Binding<Instance.ID?>,
        switchTo: @escaping (Instance.ID) -> Void
    ) -> some View {
        ForEach(instances) { instance in
            Button {
                switchTo(instance.id)
            } label: {
                Label {
                    Text(instance.label)
                } icon: {
                    Image(systemName: "internaldrive")
                        .imageScale(.large)
                        .frame(width: 22, height: 22, alignment: .center)
                        .foregroundStyle(instance.id == selection.wrappedValue ? settings.theme.tint : .primary)
                }
                .labelIconToTitleSpacing(8)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .foregroundStyle(instance.id == selection.wrappedValue ? settings.theme.tint : .primary)
            }
            .buttonStyle(.plain)
            .listRowInsets(.init(top: 0, leading: -5, bottom: 0, trailing: -5))
            .background(
                instance.id == selection.wrappedValue ? .tertiarySystemFill : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
    }
}
#endif

#Preview {
    ContentView()
        .withAppState()
}
