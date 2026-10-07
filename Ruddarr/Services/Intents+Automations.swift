import Foundation
import AppIntents

struct AddMovieIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Movie"
    static let description: IntentDescription? = IntentDescription("Adds the best match for a title or IMDb link to Radarr, using the last settings used in the app.")

    @Parameter(title: "Title", description: "Movie title, IMDb link, `imdb:` or `tmdb:` identifier.")
    var query: String

    @Parameter(title: "Automatic Search", default: false)
    var search: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$query) to Radarr") {
            \.$search
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MovieEntity> & ProvidesDialog {
        let instance = try await preferredInstance(.radarr)

        let results = try await dependencies.api.radarr.lookup(instance, lookupTerm(query))

        guard var movie = try await choose(results, { resultLabel($0.title, $0.year) }, "Which movie do you want to add?") else {
            throw AppError(String(localized: "No movie found matching “\(query)”."))
        }

        if !movie.exists {
            let defaults = dependencies.store.string(forKey: "movieDefaults")
                .flatMap(MovieDefaults.init(rawValue:)) ?? MovieDefaults()

            let profiles = try await dependencies.api.instance.qualityProfiles(instance)
            let folders = try await dependencies.api.instance.rootFolders(instance)

            movie.applyDefaults(defaults, profiles, folders)

            movie = try await dependencies.api.radarr.add(movie, instance)
        }

        if search {
            _ = try await dependencies.api.instance.command(.search([movie.id]), instance)
        }

        let label = resultLabel(movie.title, movie.year)

        let message = search
            ? String(localized: "Added \(label) and started searching for releases.")
            : String(localized: "Added \(label).")

        return .result(value: MovieEntity(movie, instance.id), dialog: "\(message)")
    }
}

struct AddSeriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Series"
    static let description: IntentDescription? = IntentDescription("Adds the best match for a title or IMDb link to Sonarr, using the last settings used in the app.")

    @Parameter(title: "Title", description: "Series title, IMDb link, `imdb:` or `tvdb:` identifier.")
    var query: String

    @Parameter(title: "Automatic Search", default: false)
    var search: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$query) to Sonarr") {
            \.$search
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<SeriesEntity> & ProvidesDialog {
        let instance = try await preferredInstance(.sonarr)

        let results = try await dependencies.api.sonarr.lookup(instance, lookupTerm(query))

        guard var series = try await choose(results, { resultLabel($0.title, $0.year) }, "Which series do you want to add?") else {
            throw AppError(String(localized: "No series found matching “\(query)”."))
        }

        if !series.exists {
            let defaults = dependencies.store.string(forKey: "seriesDefaults")
                .flatMap(SeriesDefaults.init(rawValue:)) ?? SeriesDefaults()

            let profiles = try await dependencies.api.instance.qualityProfiles(instance)
            let folders = try await dependencies.api.instance.rootFolders(instance)

            series.applyDefaults(defaults, profiles, folders)

            series = try await dependencies.api.sonarr.add(series, instance)
        }

        if search {
            _ = try await dependencies.api.instance.command(.seriesSearch(series.id), instance)
        }

        let label = resultLabel(series.title, series.year)

        let message = search
            ? String(localized: "Added \(label) and started searching for releases.")
            : String(localized: "Added \(label).")

        return .result(value: SeriesEntity(series, instance.id), dialog: "\(message)")
    }
}

struct MovieAutomaticSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Automatic Movie Search"
    static let description: IntentDescription? = IntentDescription("Searches all indexers for releases of a movie.")

    @Parameter(title: "Movie")
    var target: MovieEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Search for releases of \(\.$target)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let instance = try await instanceById(target.instanceId)

        _ = try await dependencies.api.instance.command(.search([target.movieId]), instance)

        let message = String(localized: "Started searching for \(target.title).")

        return .result(dialog: "\(message)")
    }
}

struct SeriesAutomaticSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Automatic Series Search"
    static let description: IntentDescription? = IntentDescription("Searches all indexers for releases of all monitored episodes of a series.")

    @Parameter(title: "Series")
    var target: SeriesEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Search for releases of \(\.$target)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let instance = try await instanceById(target.instanceId)

        _ = try await dependencies.api.instance.command(.seriesSearch(target.seriesId), instance)

        let message = String(localized: "Started searching for \(target.title).")

        return .result(dialog: "\(message)")
    }
}

struct UpcomingReleasesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Upcoming Releases"
    static let description: IntentDescription? = IntentDescription("Lists the movies and episodes releasing in the coming days.")

    @Parameter(title: "Days", default: 7)
    var days: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get releases for the next \(\.$days) days")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        let span = min(max(days, 1), 90)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: span, to: start) ?? start
        let instances = await MainActor.run { AppSettings.shared.configuredInstances }

        let results = await withTaskGroup(of: [UpcomingRelease]?.self, returning: [[UpcomingRelease]?].self) { group in
            for instance in instances {
                group.addTask {
                    try? await upcomingReleases(instance, start..<end)
                }
            }

            var results: [[UpcomingRelease]?] = []

            for await result in group {
                results.append(result)
            }

            return results
        }

        if !results.isEmpty, results.allSatisfy({ $0 == nil }) {
            throw AppError(String(localized: "Failed to load the calendar."))
        }

        let lines = results
            .compactMap { $0 }
            .joined()
            .sorted { $0.date < $1.date }
            .map(\.text)

        let summary = lines.isEmpty
            ? String(localized: "Nothing is releasing in the next \(span) days.")
            : lines.prefix(10).joined(separator: "\n")

        return .result(value: lines, dialog: "\(summary)")
    }
}

private struct UpcomingRelease: Sendable {
    let date: Date
    let text: String
}

private func upcomingReleases(_ instance: Instance, _ range: Range<Date>) async throws -> [UpcomingRelease] {
    switch instance.type {
    case .radarr:
        try await dependencies.api.radarr.calendar(range.lowerBound, range.upperBound, instance)
            .flatMap { movieReleases($0, range) }
    case .sonarr:
        try await dependencies.api.sonarr.calendar(range.lowerBound, range.upperBound, instance)
            .compactMap { episodeRelease($0, range) }
    }
}

private func movieReleases(_ movie: Movie, _ range: Range<Date>) -> [UpcomingRelease] {
    let releases: [(date: Date?, type: String)] = [
        (movie.inCinemas, String(localized: "In Cinemas")),
        (movie.digitalRelease, String(localized: "Digital Release")),
        (movie.physicalRelease, String(localized: "Physical Release")),
    ]

    return releases.compactMap { release in
        guard let date = release.date, range.contains(date) else { return nil }

        let day = date.formatted(.dateTime.weekday().month().day())

        return UpcomingRelease(date: date, text: "\(day) · \(movie.title) (\(release.type))")
    }
}

private func episodeRelease(_ episode: Episode, _ range: Range<Date>) -> UpcomingRelease? {
    guard let date = episode.airDateUtc, range.contains(date) else { return nil }

    let time = date.formatted(.dateTime.weekday().month().day().hour().minute())
    let parts = [episode.series?.title, episode.episodeLabel, episode.title].compactMap { $0 }

    return UpcomingRelease(date: date, text: "\(time) · \(parts.joined(separator: " · "))")
}

private extension AppIntent {
    /// Asks which lookup result to use when there is more than one.
    func choose<Item>(_ results: [Item], _ label: (Item) -> String, _ dialog: IntentDialog) async throws -> Item? {
        guard results.count > 1 else { return results.first }

        let candidates = Array(results.prefix(10))
        let options = candidates.map { IntentChoiceOption(title: "\(label($0))", style: .default) }
        let choice = try await requestChoice(between: options + [.cancel], dialog: dialog)

        return options.firstIndex(of: choice).map { candidates[$0] }
    }
}

private func resultLabel(_ title: String, _ year: Int) -> String {
    year > 0 ? "\(title) (\(year))" : title
}

private func lookupTerm(_ query: String) -> String {
    extractImdbId(query).map { "imdb:\($0)" } ?? query.trimmed()
}

@MainActor
private func preferredInstance(_ type: InstanceType) throws -> Instance {
    let settings = AppSettings.shared
    let instances = settings.configuredInstances.filter { $0.type == type }
    let selected = type == .radarr ? settings.radarrInstanceId : settings.sonarrInstanceId

    guard let instance = instances.first(where: { $0.id == selected }) ?? instances.first else {
        throw AppError(String(localized: "No \(type.rawValue) instance configured."))
    }

    return instance
}

@MainActor
private func instanceById(_ id: Instance.ID) throws -> Instance {
    guard let instance = AppSettings.shared.instanceById(id) else {
        throw AppError(String(localized: "Instance not found."))
    }

    return instance
}

private extension Movie {
    mutating func applyDefaults(_ defaults: MovieDefaults, _ profiles: [InstanceQualityProfile], _ folders: [InstanceRootFolder]) {
        let availabilities: [MovieStatus] = [.announced, .inCinemas, .released]

        addOptions = MovieAddOptions(monitor: defaults.monitor)
        monitored = defaults.monitor != .none

        minimumAvailability = availabilities.contains(defaults.minimumAvailability)
            ? defaults.minimumAvailability
            : .announced

        qualityProfileId = AddDefaults.qualityProfile(defaults.qualityProfile, in: profiles.map(\.id))
        rootFolderPath = AddDefaults.rootFolder(defaults.rootFolder, in: folders.map(\.path))
    }
}

private extension Series {
    mutating func applyDefaults(_ defaults: SeriesDefaults, _ profiles: [InstanceQualityProfile], _ folders: [InstanceRootFolder]) {
        addOptions = SeriesAddOptions(monitor: defaults.monitor)
        monitorNewItems = nil
        seasonFolder = defaults.seasonFolder

        qualityProfileId = AddDefaults.qualityProfile(defaults.qualityProfile, in: profiles.map(\.id))
        rootFolderPath = AddDefaults.rootFolder(defaults.rootFolder, in: folders.map(\.path))
    }
}
