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

    func macosWindowFrame() -> some View {
        if ProcessInfo.processInfo.isiOSAppOnMac {
            self.frame(minWidth: 1_024, maxWidth: 12_032, minHeight: 768, maxHeight: 6_768)
        } else {
            self.frame(minWidth: 1)
        }
    }
}

private struct WithAppStateModifier: ViewModifier {
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory

    func body(content: Content) -> some View {
        let settings = AppSettings()
        let radarrInstance = settings.radarrInstance ?? Instance.void

        content
            .tint(theme.tint)
            .environmentObject(settings)
            .environment(RadarrInstance(radarrInstance))
    }
}

private struct WithSettingsModifier: ViewModifier {
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory

    func body(content: Content) -> some View {
        let settings = AppSettings()

        content
            .tint(theme.tint)
            .environmentObject(settings)
    }
}
