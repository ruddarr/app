import SwiftUI
import AppIntents

struct Shortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MoviesIntent(),
            phrases: [
                "Open Movies in \(.applicationName)",
                "Show movies in rudder",
                "Show rudder movies",
                "Show Radar movies",
                "Show movie library"
            ],
            shortTitle: "Movies",
            systemImageName: "film"
        )

        AppShortcut(
            intent: SeriesIntent(),
            phrases: [
                "Open Series in \(.applicationName)",
                "Show series in rudder",
                "Show rudder series",
                "Show Sonar series",
            ],
            shortTitle: "Series",
            systemImageName: "tv"
        )

        AppShortcut(
            intent: CalendarIntent(),
            phrases: [
                "Open Calendar in \(.applicationName)",
                "Show calendar in rudder",
                "Show upcoming movies",
                "Show upcoming series",
                "Show upcoming TV series",
            ],
            shortTitle: "Calendar",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: AddMovieIntent(),
            phrases: [
                "Add Movie to \(.applicationName)",
                "Add movie to rudder",
            ],
            shortTitle: "Add Movie",
            systemImageName: "plus"
        )
    }
}

struct MoviesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Movies"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.moviesPath = .init()
        dependencies.router.selectedTab = .movies

        return .result()
    }
}

struct SeriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Series"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.seriesPath = .init()
        // dependencies.router.selectedTab = .series

        return .result()
    }
}

struct CalendarIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Calendar"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.calendarPath = .init()
        dependencies.router.selectedTab = .calendar

        return .result()
    }
}

struct AddMovieIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Movie"

    @Parameter(title: "Title")
    var title: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add Movie with \(\.$title)")
    }

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        var query: String = ""

        if let movieTitle = title, !movieTitle.isEmpty {
            query = movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        dependencies.router.moviesPath = .init()

        try? await Task.sleep(nanoseconds: 50_000_000)

        dependencies.router.moviesPath.append(
            MoviesView.Path.search(query)
        )

        dependencies.router.selectedTab = .movies

        return .result()
    }
}
