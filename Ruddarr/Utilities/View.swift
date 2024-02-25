import SwiftUI

extension View {
    func withAppState() -> some View {
        modifier(WithAppStateModifier())
    }

    func withSettings() -> some View {
        modifier(WithSettingsModifier())
    }

    func withRadarrInstance(movies: [Movie] = [], lookup: [Movie] = []) -> some View {
        let instance = RadarrInstance(.sample)
        instance.movies.items = movies

        return self.environment(instance)
    }

    func hideSidebarToggle(_ shouldHide: Bool) -> some View {
        self.toolbar(removing: shouldHide ? .sidebarToggle : nil)
    }

    func appWindowFrame() -> some View {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            self.frame(minWidth: 1_024, maxWidth: 12_032, minHeight: 768, maxHeight: 6_768)
        } else {
            self.frame(minWidth: 1)
        }
    }
}

private struct WithAppStateModifier: ViewModifier {
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic

    func body(content: Content) -> some View {
        let settings = AppSettings()
        let radarrInstance = settings.radarrInstance ?? Instance.void

        content
            .tint(theme.tint)
            .preferredColorScheme(appearance.preferredColorScheme)
            .environmentObject(settings)
            .environment(RadarrInstance(radarrInstance))
    }
}

private struct WithSettingsModifier: ViewModifier {
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic

    func body(content: Content) -> some View {
        let settings = AppSettings()

        content
            .tint(theme.tint)
            .preferredColorScheme(appearance.preferredColorScheme)
            .environmentObject(settings)
    }
}

extension ShapeStyle where Self == Color {
    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiarySystemBackground: Color { Color(UIColor.tertiarySystemBackground) }
}
