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
        instance.episodes.seed(episodes)

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

    @ViewBuilder
    func containerHorizontalMargins() -> some View {
        #if os(iOS)
            if #available(iOS 27.1, *) {
                contentMargins(for: .container, edges: .horizontal)
            } else {
                scenePadding(.horizontal)
            }
        #else
            scenePadding(.horizontal)
        #endif
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
}

private struct OnBecomeActiveModifier: ViewModifier {
    let action: () async -> Void

    func body(content: Content) -> some View {
        content.onChange(of: Lifecycle.shared.resumeCount) {
            Task { await action() }
        }
    }
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

    func body(content: Content) -> some View {
        content.presentationDetents(Set(detents.map(adaptive)))
    }

    func adaptive(_ detent: PresentationDetent) -> PresentationDetent {
        switch detent {
        case .fraction(0.25): .custom(QuarterDetent.self)
        case .fraction(0.33): .custom(ThirdDetent.self)
        case .medium: .custom(MediumDetent.self)
        case .fraction(0.7): .custom(SeventyDetent.self)
        default: detent
        }
    }
}

private protocol AdaptiveDetent: CustomPresentationDetent {
    static var fraction: CGFloat { get }
    static var expandedFraction: CGFloat { get }
}

extension AdaptiveDetent {
    static func height(in context: Context) -> CGFloat? {
        let isShortPhone = Platform.deviceType == .phone && context.maxDetentValue < 700
        let expanded = context.dynamicTypeSize > .xLarge || isShortPhone

        return context.maxDetentValue * (expanded ? expandedFraction : fraction)
    }
}

private struct QuarterDetent: AdaptiveDetent {
    static let fraction: CGFloat = 0.25
    static let expandedFraction: CGFloat = 0.35
}

private struct ThirdDetent: AdaptiveDetent {
    static let fraction: CGFloat = 0.33
    static let expandedFraction: CGFloat = 0.45
}

private struct MediumDetent: AdaptiveDetent {
    static let fraction: CGFloat = 0.5
    static let expandedFraction: CGFloat = 0.8
}

private struct SeventyDetent: AdaptiveDetent {
    static let fraction: CGFloat = 0.7
    static let expandedFraction: CGFloat = 0.9
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
