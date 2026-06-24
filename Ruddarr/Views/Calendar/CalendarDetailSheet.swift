import SwiftUI

struct CalendarDetailSheet: View {
    var selection: CalendarSelection

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        switch selection {
        case .movie(let movie):
            if let instance = instance(movie.instanceId) {
                CalendarMovieSheet(selection: selection, movie: movie, instance: instance)
            } else {
                unavailable
            }
        case .episode(let episode):
            if let instance = instance(episode.instanceId), episode.series != nil {
                CalendarEpisodeSheet(selection: selection, episode: episode, instance: instance)
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
    /// Whether the "Open" button (deep-links to the selected item) is shown.
    /// Only the destination view for the selection should offer it — e.g. the
    /// episode view, not the intermediate series or season views.
    var showsOpenButton: Bool = true

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

            if showsOpenButton {
                ToolbarItem(placement: .bottomBar) {
                    Button("Open", systemImage: "arrow.up.forward.app") {
                        inCalendarSheet.selection.jumpToTab()
                        inCalendarSheet.dismiss()
                    }
                    .tint(.primary)
                }

                // Pin the "Open" button to the left of the bottom bar.
                ToolbarSpacer(.flexible, placement: .bottomBar)
            }
        }
    }
}

private struct CalendarMovieSheet: View {
    private let movieId: Movie.ID
    private let selection: CalendarSelection

    @State private var path = NavigationPath()
    @State private var instance: RadarrInstance

    @Environment(\.dismiss) private var dismiss

    init(selection: CalendarSelection, movie: Movie, instance model: Instance) {
        let instance = RadarrInstance(model)
        instance.movies.items = [movie]
        instance.movies.cachedItems = [movie]
        instance.movies.itemsCount = 1

        self.selection = selection
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
        .inCalendarSheet(selection: selection) {
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
    private let selection: CalendarSelection

    @State private var path: NavigationPath
    @State private var instance: SonarrInstance

    @Environment(\.dismiss) private var dismiss

    init(selection: CalendarSelection, episode: Episode, instance model: Instance) {
        let instance = SonarrInstance(model)

        if let series = episode.series {
            instance.series.items = [series]
            instance.series.cachedItems = [series]
            instance.series.itemsCount = 1
        }

        instance.episodes.items = [episode]

        self.selection = selection
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
        .inCalendarSheet(selection: selection) {
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
            toolbar { CalendarSheetAwareToolbar() }
        } else {
            self
        }
    }
}
