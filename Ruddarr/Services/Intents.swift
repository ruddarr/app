import AppIntents

struct OpenAppIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Ruddarr"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Tab", default: .movies)
    var target: TabItem.Openable

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.moviesPath = .init()
        dependencies.router.seriesPath = .init()

        dependencies.router.selectedTab = target.tab

        return .result()
    }
}

struct SearchMovieIntent: AppIntent {
    static var title: LocalizedStringResource = "Search for Movie"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Title")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Search for movie with \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        var query: String = ""

        if let movieTitle = name, !movieTitle.isEmpty {
            query = movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        dependencies.router.moviesPath = .init()

        try? await Task.sleep(nanoseconds: 50_000_000)

        dependencies.router.moviesPath.append(
            MoviesPath.search(query)
        )

        dependencies.router.selectedTab = .movies

        return .result()
    }
}

struct SearchSeriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search for TV Series"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Title")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Search for TV series with \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        var query: String = ""

        if let seriesTitle = name, !seriesTitle.isEmpty {
            query = seriesTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        dependencies.router.seriesPath = .init()

        try? await Task.sleep(nanoseconds: 50_000_000)

        dependencies.router.seriesPath.append(
            SeriesPath.search(query)
        )

        dependencies.router.selectedTab = .series

        return .result()
    }
}
