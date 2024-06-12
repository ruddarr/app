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
        .onAppear {
            dependencies.router.selectedTab = settings.tab
        }
        .onChange(of: controlActiveState, handleScenePhaseChange)
    }

    var sidebar: some View {
        List(selection: dependencies.$router.selectedTab.optional) {
            ForEach(Tab.allCases) { tab in
                if tab != .settings {
                    NavigationLink(value: tab, label: { tab.label })
                }
            }
        }
        .frame(minWidth: 220)
        .toolbar(removing: .sidebarToggle)
        .safeAreaInset(edge: .bottom) {
            List(selection: dependencies.$router.selectedTab.optional) {
                ForEach(Tab.allCases) { tab in
                    if tab == .settings {
                        NavigationLink(value: tab, label: { tab.label })
                    }
                }
            }
            .frame(height: 48)
            .scrollDisabled(true)
        }
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView()
        case .series:
            SeriesView()
        case .activity:
            ActivityView()
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
