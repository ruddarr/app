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

        AppShortcut(
            intent: AddSeriesIntent(),
            phrases: [
                "Add Series to \(.applicationName)",
                "Add TV Series to \(.applicationName)",
                "Add series to rudder",
                "Add tv series to rudder",
            ],
            shortTitle: "Add Series",
            systemImageName: "plus"
        )
    }
}
