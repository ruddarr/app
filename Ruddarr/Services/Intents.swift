import AppIntents

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
        dependencies.router.selectedTab = .series

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
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add Movie with \(\.$name)")
    }

    static var openAppWhenRun: Bool = true

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

struct AddSeriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Add TV Series"

    @Parameter(title: "Title")
    var title: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add TV Series with \(\.$title)")
    }

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        var query: String = ""

        if let seriesTitle = title, !seriesTitle.isEmpty {
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

@available(iOS 18.0, *)
@AssistantIntent(schema: .system.search)
struct SystemSearchMoviesIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.movies]

    @Parameter(title: "Criteria")
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.moviesPath = .init()
        dependencies.router.selectedTab = .movies

        try? await Task.sleep(nanoseconds: 50_000_000)

        dependencies.router.moviesPath.append(
            MoviesPath.search(criteria.term.trimmingCharacters(in: .whitespaces))
        )

        return .result()
    }
}

@available(iOS 18.0, *)
@AssistantIntent(schema: .system.search)
struct SystemSearchSeriesIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.tv]

    @Parameter(title: "Criteria")
    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        dependencies.router.seriesPath = .init()
        dependencies.router.selectedTab = .series

        try? await Task.sleep(nanoseconds: 50_000_000)

        dependencies.router.seriesPath.append(
            SeriesPath.search(criteria.term.trimmingCharacters(in: .whitespaces))
        )

        return .result()
    }
}
