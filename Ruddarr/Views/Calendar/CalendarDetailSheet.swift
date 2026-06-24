import SwiftUI

struct CalendarDetailSheet: View {
    var selection: CalendarSelection

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        switch selection {
        case .movie(let movie):
            if let instance = instance(movie.instanceId) {
                CalendarMovieSheet(movie: movie, instance: instance)
            } else {
                unavailable
            }
        case .episode(let episode):
            if let instance = instance(episode.instanceId), episode.series != nil {
                CalendarEpisodeSheet(episode: episode, instance: instance)
            } else {
                unavailable
            }
        }
    }

    var unavailable: some View {
        ContentUnavailableView("An error occurred.", systemImage: "exclamationmark.triangle")
    }

    func instance(_ instanceId: Instance.ID?) -> Instance? {
        instanceId.flatMap(settings.instanceById)
    }
}

struct CalendarSheetAwareToolbar: ToolbarContent {
    var deeplink: URL?

    @Environment(\.inCalendarSheet) private var inCalendarSheet

    var body: some ToolbarContent {
        if let inCalendarSheet {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    inCalendarSheet.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .accessibilityLabel("Close")
            }

            if let deeplink {
                ToolbarItem(placement: .bottomBar) {
                    Button("Open", systemImage: "arrow.up.forward.app") {
                        try? QuickActions.Deeplink(url: deeplink)()
                        inCalendarSheet.dismiss()
                    }
                    .tint(.primary)
                }

                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
        }
    }
}

private struct CalendarMovieSheet: View {
    private let movieId: Movie.ID

    @State private var path = NavigationPath()
    @State private var instance: RadarrInstance

    @Environment(\.dismiss) private var dismiss

    init(movie: Movie, instance model: Instance) {
        let instance = RadarrInstance(model)
        instance.movies.items = [movie]
        instance.movies.cachedItems = [movie]
        instance.movies.itemsCount = 1

        self.movieId = movie.id
        self._instance = State(initialValue: instance)
    }

    var body: some View {
        NavigationStack(path: $path) {
            MovieView(movie: instance.movies.byId(movieId))
                .navigationDestination(for: MoviesPath.self) {
                    destination(for: $0)
                }
        }
        .environment(instance)
        .inCalendarSheet {
            dismiss()
        }
        .displayToasts()
    }

    func destination(for path: MoviesPath) -> some View {
        let needsToolbar = if case .movie = path { false } else { true }

        return MoviesDestination(path: path)
            .calendarSheetToolbar(needsToolbar)
    }
}

private struct CalendarEpisodeSheet: View {
    private let seriesId: Series.ID

    @State private var path: NavigationPath
    @State private var instance: SonarrInstance

    @Environment(\.dismiss) private var dismiss

    init(episode: Episode, instance model: Instance) {
        let instance = SonarrInstance(model)

        if let series = episode.series {
            instance.series.items = [series]
            instance.series.cachedItems = [series]
            instance.series.itemsCount = 1
        }

        instance.episodes.items = [episode]

        self.seriesId = episode.seriesId

        var path = NavigationPath()
        path.append(SeriesPath.season(episode.seriesId, episode.seasonNumber))

        if !episode.isGroupedInCalendar {
            path.append(SeriesPath.episode(episode.seriesId, episode.id))
        }

        self._path = State(initialValue: path)
        self._instance = State(initialValue: instance)
    }

    var body: some View {
        NavigationStack(path: $path) {
            SeriesDetailView(series: instance.series.byId(seriesId))
                .navigationDestination(for: SeriesPath.self) {
                    destination(for: $0)
                }
        }
        .environment(instance)
        .inCalendarSheet {
            dismiss()
        }
        .displayToasts()
    }

    func destination(for destination: SeriesPath) -> some View {
        let needsToolbar: Bool = switch destination {
        case .series, .season, .episode: false
        default: true
        }

        return SeriesDestination(path: destination, navigate: { path.append($0) })
            .calendarSheetToolbar(needsToolbar)
    }
}

extension View {
    @ViewBuilder
    func calendarSheetToolbar(_ enabled: Bool = true) -> some View {
        if enabled {
            toolbar {
                CalendarSheetAwareToolbar()
            }
        } else {
            self
        }
    }
}
