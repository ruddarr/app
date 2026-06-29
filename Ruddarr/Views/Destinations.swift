import SwiftUI

struct MoviesDestination: View {
    var path: MoviesPath

    @Environment(AppSettings.self) var settings
    @Environment(RadarrInstance.self) var instance

    var body: some View {
        switch path {
        case .search(let query):
            MovieSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            if let data, let movie = try? JSONDecoder().decode(Movie.self, from: data) {
                MoviePreviewView(movie: movie)
                    .environment(instance)
                    .environment(settings)
            }
        case .movie(let id):
            MovieView(movie: instance.movies.byId(id))
                .environment(instance)
                .environment(settings)
        case .edit(let id):
            MovieEditView(movie: instance.movies.byId(id))
                .environment(instance)
        case .releases(let id):
            MovieReleasesView(movie: instance.movies.byId(id))
                .environment(instance)
                .environment(settings)
        case .metadata(let id):
            MovieMetadataView(movie: instance.movies.byId(id))
                .environment(instance)
        }
    }
}

struct SeriesDestination: View {
    var path: SeriesPath
    var navigate: (SeriesPath) -> Void = { dependencies.router.seriesPath.append($0) }

    @Environment(AppSettings.self) var settings
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        switch path {
        case .search(let query):
            SeriesSearchView(searchQuery: query)
                .environment(instance)
        case .preview(let data):
            if let data, let series = try? JSONDecoder().decode(Series.self, from: data) {
                SeriesPreviewView(series: series)
                    .environment(instance)
                    .environment(settings)
            }
        case .series(let id):
            SeriesDetailView(series: instance.series.byId(id))
                .environment(instance)
                .environment(settings)
        case .edit(let id):
            SeriesEditView(series: instance.series.byId(id))
                .environment(instance)
        case .releases(let id, let season, let episode):
            SeriesReleasesView(
                series: instance.series.byId(id),
                seasonId: season,
                episodeId: episode
            )
            .environment(instance)
            .environment(settings)
        case .season(let id, let season, let episode):
            SeasonView(
                series: instance.series.byId(id),
                seasonId: season,
                navigate: navigate,
                jumpToEpisode: episode
            )
                .environment(instance)
                .environment(settings)
        case .episode(let id, let episode):
            EpisodeView(series: instance.series.byId(id), episodeId: episode)
                .environment(instance)
                .environment(settings)
        }
    }
}

struct SettingsDestination: View {
    var path: SettingsView.Path

    @Environment(AppSettings.self) var settings
    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    var body: some View {
        switch path {
        case .icons:
            IconsView()
                .environment(settings)
        case .changelog:
            ChangelogView()
        case .createInstance:
            InstanceEditView(mode: .create, instance: Instance())
                .environment(radarrInstance)
                .environment(sonarrInstance)
                .environment(settings)
        case .viewInstance(let instanceId):
            if let instance = settings.instanceById(instanceId) {
                InstanceView(instance: instance)
                    .environment(radarrInstance)
                    .environment(sonarrInstance)
                    .environment(settings)
            }
        case .editInstance(let instanceId):
            if let instance = settings.instanceById(instanceId) {
                InstanceEditView(mode: .update, instance: instance)
                    .environment(radarrInstance)
                    .environment(sonarrInstance)
                    .environment(settings)
            }
        }
    }
}
