import SwiftUI

#if os(macOS)
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    @Environment(\.controlActiveState) var controlActiveState

    var body: some View {
        NavigationSplitView(
            sidebar: {
                sidebar
            },
            detail: {
                screen(for: dependencies.router.selectedTab)
            }
        )
        .displayToasts()
        .whatsNewSheet()
        .onChange(of: controlActiveState, handleScenePhaseChange)
    }

    var sidebar: some View {
        List(selection: dependencies.$router.selectedTab.optional) {
            ForEach(Tab.allCases) { tab in
                if tab != .settings {
                    sidebarItem(for: tab)
                }
            }
        }
        .frame(minWidth: 220)
        .toolbar(removing: .sidebarToggle)
        .safeAreaInset(edge: .bottom) {
            List(selection: dependencies.$router.selectedTab.optional) {
                ForEach(Tab.allCases) { tab in
                    if tab == .settings {
                        sidebarItem(for: tab)
                    }
                }
            }
            .frame(height: 48)
            .scrollDisabled(true)
        }
    }

    @ViewBuilder
    func sidebarItem(for tab: Tab) -> some View {
        NavigationLink(
            destination: screen(for: tab),
            tag: tab,
            selection: dependencies.$router.selectedTab.optional
        ) {
            tab.label
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

    func handleScenePhaseChange() {
        // TODO: [macOS] Test this
        if controlActiveState == .key {
            Notifications.shared.maybeUpdateWebhooks(settings)
            Telemetry.shared.maybeUploadTelemetry(settings)
        }
    }
}

#Preview {
    ContentView()
        .withAppState()
}
#endif
