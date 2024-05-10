import SwiftUI

extension View {
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

    func appWindowFrame() -> some View {
        #if os(macOS)
            self.frame(minWidth: 1_280, maxWidth: 12_032, minHeight: 768, maxHeight: 6_768)
        #else
            return self
        #endif
    }

    func viewPadding(_ edges: Edge.Set = .all) -> some View {
        self.modifier(ViewPadding(edges))
    }
}

private struct WithAppStateModifier: ViewModifier {
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic

    func body(content: Content) -> some View {
        let settings = AppSettings()
        let radarrInstance = settings.radarrInstance ?? Instance.radarrVoid
        let sonarrInstance = settings.sonarrInstance ?? Instance.sonarrVoid

        content
            .tint(theme.tint)
            .preferredColorScheme(appearance.preferredColorScheme)
            .environmentObject(settings)
            .environment(\.deviceType, Platform.deviceType())
            .environment(RadarrInstance(radarrInstance))
            .environment(SonarrInstance(sonarrInstance))
    }
}

private struct ViewPadding: ViewModifier {
    var edges: Edge.Set

    @Environment(\.deviceType) private var deviceType

    init(_ edges: Edge.Set) {
        self.edges = edges
    }

    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.scenePadding(edges)
        } else {
            content.padding(edges, 22)
        }
    }
}

extension SearchFieldPlacement {
    static let drawerOrToolbar: SearchFieldPlacement = {
        #if os(macOS)
            .toolbar
        #else
            .navigationBarDrawer(displayMode: .always)
        #endif
    }()
}

extension Image {
    init(appIcon: String) {
        #if os(macOS)
            self.init(nsImage: NSImage(named: appIcon) ?? NSImage())
        #else
            self.init(uiImage: UIImage(named: appIcon)!)
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
            return .automatic
        case .inline:
            return .inline
        case .large:
            return .large
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

extension ShapeStyle where Self == Color {
#if os(iOS)
    static var label: Color { Color(UIColor.label) }

    static var darkGray: Color { Color(UIColor.darkGray) }
    static var darkText: Color { Color(UIColor.darkText) }

    static var lightGray: Color { Color(UIColor.lightGray) }
    static var lightText: Color { Color(UIColor.lightText) }

    static var systemFill: Color { Color(UIColor.systemFill) }
    static var secondarySystemFill: Color { Color(UIColor.secondarySystemFill) }

    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiarySystemBackground: Color { Color(UIColor.tertiarySystemBackground) }
#else
    static var label: Color { Color(nsColor: .labelColor) }

    static var darkGray: Color { Color(NSColor.darkGray) }
    static var darkText: Color { Color(NSColor.secondaryLabelColor) }

    static var lightGray: Color { Color(NSColor.lightGray) }
    static var lightText: Color { Color(NSColor.secondaryLabelColor) }

    static var systemFill: Color { Color(NSColor.systemFill) }
    static var secondarySystemFill: Color { Color(NSColor.secondarySystemFill) }

    static var systemBackground: Color { Color(NSColor.windowBackgroundColor) }
    static var secondarySystemBackground: Color { Color(NSColor.controlBackgroundColor) }
    static var tertiarySystemBackground: Color { Color(NSColor.underPageBackgroundColor) }
#endif
}
