import SwiftUI

extension View {
    func withAppState() -> some View {
        let settings = AppSettings()
        let radarrInstance = settings.radarrInstance ?? Instance.void

        return self
            .tint(settings.accentColor())
            .environmentObject(settings)
            .environment(RadarrInstance(radarrInstance))
    }

    func withSettings() -> some View {
        let settings = AppSettings()

        return self
            .tint(settings.accentColor())
            .environmentObject(AppSettings())
    }

    func withRadarrInstance(movies: [Movie] = [], lookup: [Movie] = []) -> some View {
        let instance = RadarrInstance(.sample)
        instance.movies.items = movies

        return self.environment(instance)
    }
}
