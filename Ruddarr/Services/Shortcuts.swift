import AppIntents

struct Shortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchMovieIntent(),
            phrases: [
                "Search for movie in \(.applicationName)",
                "Add movie to \(.applicationName)",
            ],
            shortTitle: "Add Movie",
            systemImageName: "plus"
        )

        AppShortcut(
            intent: SearchSeriesIntent(),
            phrases: [
                "Search for series in \(.applicationName)",
                "Search for TV series in \(.applicationName)",
                "Add series to \(.applicationName)",
                "Add TV series to \(.applicationName)",
            ],
            shortTitle: "Add Series",
            systemImageName: "plus"
        )

        AppShortcut(
            intent: UpcomingReleasesIntent(),
            phrases: [
                "What's coming up in \(.applicationName)",
                "Show upcoming releases in \(.applicationName)",
                "Read the \(.applicationName) calendar",
            ],
            shortTitle: "Upcoming Releases",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: OpenAppIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open \(.applicationName) \(\.$target)",
                "Show \(.applicationName) \(\.$target)",
                "Open \(\.$target) in \(.applicationName)",
                "Show \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Ruddarr",
            systemImageName: "arrow.up.forward.app"
        )
    }
}
