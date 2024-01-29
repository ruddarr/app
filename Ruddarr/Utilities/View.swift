import SwiftUI

extension View {
    func withAppState() -> some View {
        let settings = AppSettings()
        let radarrInstance = settings.radarrInstance ?? Instance.void

        return self
            .environmentObject(settings)
            .environment(RadarrInstance(radarrInstance))
    }

    func withSettings() -> some View {
        return self
            .environmentObject(AppSettings())
    }

    func withRadarrInstance(movies: [Movie] = [], lookup: [Movie] = []) -> some View {
        let instance = RadarrInstance(.sample)
        instance.movies.items = movies

        return self.environment(instance)
    }
}
