import SwiftUI

struct CalendarAwareToolbarMenu<Menu: ToolbarContent>: ToolbarContent {
    private let menu: () -> Menu

    init(@ToolbarContentBuilder menu: @escaping () -> Menu) {
        self.menu = menu
    }

    var body: some ToolbarContent {
        // Keep the view's own actions (monitor, overflow menu, …) and, when
        // presented inside the calendar sheet, add the close/jump buttons.
        menu()
        CalendarSheetToolbarContent()
    }
}

enum CalendarSelection: Identifiable {
    case movie(Movie)
    case episode(Episode)

    var id: String {
        switch self {
        case .movie(let movie):
            "movie:\(movie.instanceId?.uuidString ?? "unknown"):\(movie.id)"
        case .episode(let episode):
            "episode:\(episode.instanceId?.uuidString ?? "unknown"):\(episode.id)"
        }
    }

    func jumpToTab() {
        guard let deeplink else { return }
        try? QuickActions.Deeplink(url: deeplink)()
    }

    var deeplink: URL? {
        switch self {
        case .movie(let movie): movie.calendarDeeplink
        case .episode(let episode): episode.calendarDeeplink
        }
    }
}

struct CalendarSheetContext: @unchecked Sendable {
    let selection: CalendarSelection
    let dismiss: () -> Void
}

private struct CalendarSheetContextKey: EnvironmentKey {
    static let defaultValue: CalendarSheetContext? = nil
}

extension EnvironmentValues {
    var calendarSheetContext: CalendarSheetContext? {
        get { self[CalendarSheetContextKey.self] }
        set { self[CalendarSheetContextKey.self] = newValue }
    }
}

struct CalendarDetailSheet: View {
    var selection: CalendarSelection

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch selection {
        case .movie(let movie):
            if let instance = instance(for: movie) {
                CalendarMovieSheet(selection: selection, movie: movie, instance: instance)
            } else {
                unavailable
            }
        case .episode(let episode):
            if let instance = instance(for: episode), episode.series != nil {
                CalendarEpisodeSheet(selection: selection, episode: episode, instance: instance)
            } else {
                unavailable
            }
        }
    }

    var unavailable: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Unable to Open", systemImage: "exclamationmark.triangle")
            } description: {
                Text("The selected item no longer has a matching instance.")
            }
            .toolbar { closeButton }
        }
    }

    @ToolbarContentBuilder
    var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .tint(.primary)
            .accessibilityLabel("Dismiss")
        }
    }

    func instance(for movie: Movie) -> Instance? {
        guard let instanceId = movie.instanceId else { return nil }
        return settings.instanceById(instanceId)
    }

    func instance(for episode: Episode) -> Instance? {
        guard let instanceId = episode.instanceId else { return nil }
        return settings.instanceById(instanceId)
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
        .calendarSheetContext(selection: selection) {
            dismiss()
        }
        .displayToasts()
    }

    @ViewBuilder
    func destination(for path: MoviesPath) -> some View {
        switch path {
        case .movie:
            MoviesDestination(path: path)
        default:
            MoviesDestination(path: path)
                .calendarSheetToolbar()
        }
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
        .calendarSheetContext(selection: selection) {
            dismiss()
        }
        .displayToasts()
    }

    @ViewBuilder
    func destination(for destination: SeriesPath) -> some View {
        switch destination {
        case .series, .season, .episode:
            SeriesDestination(path: destination, navigate: { path.append($0) })
        default:
            SeriesDestination(path: destination, navigate: { path.append($0) })
                .calendarSheetToolbar()
        }
    }
}

struct CalendarSheetToolbarContent: ToolbarContent {
    @Environment(\.calendarSheetContext) private var calendarSheetContext

    var body: some ToolbarContent {
        if let calendarSheetContext {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    calendarSheetContext.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .accessibilityLabel("Dismiss")
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Jump", systemImage: "arrow.up.forward.app") {
                    calendarSheetContext.selection.jumpToTab()
                    calendarSheetContext.dismiss()
                }
                .tint(.primary)
            }
        }
    }
}

private struct CalendarSheetContextModifier: ViewModifier {
    var selection: CalendarSelection
    var dismiss: () -> Void

    func body(content: Content) -> some View {
        content.environment(\.calendarSheetContext, CalendarSheetContext(
            selection: selection,
            dismiss: dismiss
        ))
    }
}

private struct CalendarSheetToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            CalendarSheetToolbarContent()
        }
    }
}

private extension View {
    func calendarSheetContext(selection: CalendarSelection, dismiss: @escaping () -> Void) -> some View {
        modifier(CalendarSheetContextModifier(selection: selection, dismiss: dismiss))
    }

    func calendarSheetToolbar() -> some View {
        modifier(CalendarSheetToolbarModifier())
    }
}
