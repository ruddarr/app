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
}

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
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic

    // Owns the app-wide `@Observable` settings with a stable identity across body
    // re-renders (an `@Observable` injected via `.environment` must be held in `@State`).
    @State private var settings = AppSettings()

    func body(content: Content) -> some View {
        let radarrInstance = settings.radarrInstance ?? Instance.radarrVoid
        let sonarrInstance = settings.sonarrInstance ?? Instance.sonarrVoid

        content
            .tint(theme.tint)
            .preferredColorScheme(appearance.preferredColorScheme)
            .environment(settings)
            .environment(\.deviceType, Platform.deviceType)
            .environment(RadarrInstance(radarrInstance))
            .environment(SonarrInstance(sonarrInstance))
            .task {
                Queue.shared.instances = settings.instances
                setSentryContext(for: "Configuration", settings.context())
                await setSentryCloudKitContext()
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

    @Environment(\.sizeCategory) var sizeCategory

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
            switch displayMode {
            case .automatic: return .navigationBarDrawer(displayMode: .automatic)
            case .always: return .navigationBarDrawer(displayMode: .always)
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
