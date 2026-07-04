import SwiftUI

extension View {
    func onBecomeActive(perform action: @escaping () async -> Void) -> some View {
        self.modifier(OnBecomeActiveModifier(action: action))
    }

    func withAppState() -> some View {
        modifier(WithAppStateModifier())
    }

    func withRadarrInstance(movies: [Movie] = []) -> some View {
        let instance = RadarrInstance(.radarrDummy)
        instance.movies.items = movies

        return self.environment(instance)
    }

    func withSonarrInstance(series: [Series] = [], episodes: [Episode] = []) -> some View {
        let instance = SonarrInstance(.sonarrDummy)
        instance.series.items = series
        instance.episodes.items = episodes

        return self.environment(instance)
    }

    @MainActor
    func tracksQueueStatus(_ key: QueueKey?, into status: Binding<QueueItemStatus?>) -> some View {
        onReceive(Queue.shared.statuses) { statuses in
            let value = key.flatMap { statuses[$0] }
            if value != status.wrappedValue { status.wrappedValue = value }
        }
    }

    func viewBottomPadding() -> some View {
        self.modifier(ViewBottomPadding())
    }

    func prominentGlassButtonStyle(_ condition: Bool) -> some View {
        modifier(ProminentGlassButtonStyle(condition: condition))
    }

    func hideIconOnMac() -> some View {
        modifier(HideIconOnMac())
    }

    func macPreviewFrame() -> some View {
        modifier(MacPreviewFrame())
    }

    func presentationDetents(dynamic: Set<PresentationDetent>) -> some View {
        self.modifier(DynamicPresentationDetents(detents: dynamic))
    }

    func presentationDetents(
        dynamic: Set<PresentationDetent>,
        selection: Binding<PresentationDetent>
    ) -> some View {
        self.modifier(DynamicPresentationDetents(detents: dynamic, selection: selection))
    }

    func sensoryAlert<E: LocalizedError, A: View, M: View>(
        isPresented: Binding<Bool>,
        error: E?,
        @ViewBuilder actions: (E) -> A,
        @ViewBuilder message: (E) -> M
    ) -> some View {
        self
            .alert(isPresented: isPresented, error: error, actions: actions, message: message)
            .sensoryFeedback(.error, trigger: isPresented.wrappedValue) { _, presented in
                presented
            }
    }

    // Collapses a `.searchable` search bar before the app leaves the foreground,
    // or the screen leaves the window because another tab was selected. UIKit
    // traps when restoring a suspended search presentation on iOS 26.4+.
    func dismissSearchWhenHidden(_ isPresented: Binding<Bool>) -> some View {
        #if os(iOS)
            modifier(DismissSearchWhenHidden(isPresented: isPresented))
        #else
            self
        #endif
    }
}

#if os(iOS)
private struct DismissSearchWhenHidden: ViewModifier {
    @Binding var isPresented: Bool

    @State private var tab: TabItem?
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                tab = dependencies.router.selectedTab
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    collapse()
                }
            }
            .onDisappear {
                if tab != dependencies.router.selectedTab {
                    collapse()
                }
            }
    }

    private func collapse() {
        if isPresented {
            isPresented = false
        }
    }
}
#endif

private struct OnBecomeActiveModifier: ViewModifier {
    let action: () async -> Void

#if os(macOS)
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        content.onChange(of: appearsActive, initial: true) {
            guard appearsActive else { return }
            Task { await action() }
        }
    }
#else
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }

            Task { await action() }
        }
    }
#endif
}

private struct WithAppStateModifier: ViewModifier {
    @State private var settings: AppSettings
    @State private var radarrInstance: RadarrInstance
    @State private var sonarrInstance: SonarrInstance

    @MainActor
    init() {
        let settings = AppSettings.shared
        _settings = State(initialValue: settings)
        _radarrInstance = State(initialValue: RadarrInstance(settings.radarrInstance ?? .radarrVoid))
        _sonarrInstance = State(initialValue: SonarrInstance(settings.sonarrInstance ?? .sonarrVoid))
    }

    func body(content: Content) -> some View {
        content
            .tint(settings.theme.tint)
            .preferredColorScheme(settings.appearance.preferredColorScheme)
            .environment(settings)
            .environment(\.deviceType, Platform.deviceType)
            .environment(radarrInstance)
            .environment(sonarrInstance)
            .task {
                Queue.shared.instances = settings.instances
                setSentryContext(for: "Configuration", settings.context())
                await setSentryCloudKitContext()
            }
            .onChange(of: settings.instances) {
                Queue.shared.instances = settings.instances
            }
    }
}

private struct ViewBottomPadding: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.padding(.bottom)
        } else {
            content
        }
    }
}

struct ProminentGlassButtonStyle: ViewModifier {
    let condition: Bool

    func body(content: Content) -> some View {
        if condition {
            content.buttonStyle(.glassProminent)
        } else {
            content
        }
    }
}

struct HideIconOnMac: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
            content.labelStyle(.titleOnly)
        #else
            content
        #endif
    }
}

struct MacPreviewFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
            content.frame(minWidth: 900, minHeight: 600)
        #else
            content
        #endif
    }
}

private struct DynamicPresentationDetents: ViewModifier {
    var detents: Set<PresentationDetent>
    var selection: Binding<PresentationDetent>?

    @Environment(\.sizeCategory) private var sizeCategory

    @ViewBuilder
    func body(content: Content) -> some View {
        if let selection {
            content.presentationDetents(adjustedDetents, selection: selection)
        } else {
            content.presentationDetents(adjustedDetents)
        }
    }

    var adjustedDetents: Set<PresentationDetent> {
        Set(detents.map {
            switch $0 {
            case .medium: medium
            case .fraction(0.25): quarter
            case .fraction(0.33): third
            case .fraction(0.7): seventy
            default: $0
            }
        })
    }

    var medium: PresentationDetent {
        switch sizeCategory {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            .medium
        default:
            .fraction(0.8)
        }
    }

    var quarter: PresentationDetent {
        switch sizeCategory {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            .fraction(0.25)
        default:
            .fraction(0.35)
        }
    }

    var third: PresentationDetent {
        switch sizeCategory {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            .fraction(0.33)
        default:
            .fraction(0.45)
        }
    }

    var seventy: PresentationDetent {
        switch sizeCategory {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            .fraction(0.7)
        default:
            .fraction(0.9)
        }
    }
}

extension SearchFieldPlacement {
    enum DrawerDisplayMode { case automatic, always }

    static var drawerOrToolbar: SearchFieldPlacement {
        // This used to be `.navigationBarDrawer(displayMode: .automatic)`
        // but that started crashing in iOS 26.4
        .toolbar
    }

    static func drawerOrToolbar(_ displayMode: DrawerDisplayMode) -> SearchFieldPlacement {
        #if os(macOS)
            return .toolbar
        #else
            return switch displayMode {
            case .automatic: .navigationBarDrawer(displayMode: .automatic)
            case .always: .navigationBarDrawer(displayMode: .always)
            }
        #endif
    }
}

enum NavigationBarItemTitleDisplayMode {
    case automatic
    case inline
    case large

    #if os(iOS)
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .automatic:
            .automatic
        case .inline:
            .inline
        case .large:
            .large
        }
    }
    #endif
}

extension View {
    @ViewBuilder
    func safeNavigationBarTitleDisplayMode(_ displayMode: NavigationBarItemTitleDisplayMode) -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(displayMode.titleDisplayMode)
        #else
            self
        #endif
    }
}
