import AppIntents

struct Shortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MoviesIntent(),
            phrases: [
                "Open movies in \(.applicationName)",
                "Show movies in \(.applicationName)",
                "Show \(.applicationName) movies",
            ],
            shortTitle: "Movies",
            systemImageName: "film"
        )

        AppShortcut(
            intent: SeriesIntent(),
            phrases: [
                "Open series in \(.applicationName)",
                "Open TV series in \(.applicationName)",
                "Show series in \(.applicationName)",
                "Show TV series in \(.applicationName)",
                "Show \(.applicationName) series",
                "Show \(.applicationName) TV series",
            ],
            shortTitle: "Series",
            systemImageName: "tv"
        )

        AppShortcut(
            intent: CalendarIntent(),
            phrases: [
                "Open calendar in \(.applicationName)",
                "Show calendar in \(.applicationName)",
                "Show \(.applicationName) calendar",
                "Show upcoming movies in \(.applicationName)",
                "Show upcoming series in \(.applicationName)",
                "Show upcoming TV series in \(.applicationName)",
            ],
            shortTitle: "Calendar",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: AddMovieIntent(),
            phrases: [
                "Add movie to \(.applicationName)",
                "Search for movie in \(.applicationName)",
            ],
            shortTitle: "Add Movie",
            systemImageName: "plus"
        )

        AppShortcut(
            intent: AddSeriesIntent(),
            phrases: [
                "Add series to \(.applicationName)",
                "Add TV Series to \(.applicationName)",
                "Search for series in \(.applicationName)",
                "Search for TV Series in \(.applicationName)",
            ],
            shortTitle: "Add Series",
            systemImageName: "plus"
        )
    }
}
