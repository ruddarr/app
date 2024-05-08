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
        if ProcessInfo.processInfo.isiOSAppOnMac {
            self.frame(minWidth: 1_280, maxWidth: 12_032, minHeight: 768, maxHeight: 6_768)
        } else {
            self.frame(minWidth: 1)
        }
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
            .environment(RadarrInstance(radarrInstance))
            .environment(SonarrInstance(sonarrInstance))
    }
}

private struct ViewPadding: ViewModifier {
    var edges: Edge.Set

    init(_ edges: Edge.Set) {
        self.edges = edges
    }

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.scenePadding(edges)
        } else {
            content.padding(edges, 22)
        }
    }
}

extension ShapeStyle where Self == Color {
    static var lightGray: Color { Color(UIColor.lightGray) }
    static var lightText: Color { Color(UIColor.lightText) }

    static var systemFill: Color { Color(UIColor.systemFill) }

    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiarySystemBackground: Color { Color(UIColor.tertiarySystemBackground) }
}
