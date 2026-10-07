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

        let alreadyAdded = movie.exists

        if !alreadyAdded {
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

        let message = addedMessage(resultLabel(movie.title, movie.year), alreadyAdded: alreadyAdded, search: search)

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

        let alreadyAdded = series.exists

        if !alreadyAdded {
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

        let message = addedMessage(resultLabel(series.title, series.year), alreadyAdded: alreadyAdded, search: search)

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

struct MissingSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Search All Missing"
    static let description: IntentDescription? = IntentDescription("Searches all indexers for every monitored movie or episode that is missing, on all instances.")

    @Parameter(title: "Media", default: .all)
    var scope: MissingSearchScope

    static var parameterSummary: some ParameterSummary {
        Summary("Search for all missing \(\.$scope)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let configured = await MainActor.run { AppSettings.shared.configuredInstances }
        let instances = configured.filter { scope.types.contains($0.type) }

        guard !instances.isEmpty else {
            throw AppError(String(localized: "No instances configured."))
        }

        let failed = await withTaskGroup(of: Instance?.self, returning: [Instance].self) { group in
            for instance in instances {
                group.addTask {
                    let command: InstanceCommand = instance.type == .radarr ? .missingMoviesSearch : .missingEpisodesSearch

                    do {
                        _ = try await dependencies.api.instance.command(command, instance)
                        return nil
                    } catch {
                        return instance
                    }
                }
            }

            var failed: [Instance] = []

            for await instance in group {
                if let instance { failed.append(instance) }
            }

            return failed
        }

        let failedLabels = failed.map(\.label).formatted(.list(type: .and))

        if failed.count == instances.count {
            throw AppError(String(localized: "Couldn't start the search on \(failedLabels)."))
        }

        let started = Set(instances.filter { instance in !failed.contains { $0.id == instance.id } }.map(\.type))

        var message = if started == [.radarr] {
            String(localized: "Started searching for missing movies.")
        } else if started == [.sonarr] {
            String(localized: "Started searching for missing episodes.")
        } else {
            String(localized: "Started searching for missing movies and episodes.")
        }

        if !failed.isEmpty {
            message += " " + String(localized: "Couldn't start the search on \(failedLabels).")
        }

        return .result(dialog: "\(message)")
    }
}

enum MissingSearchScope: String, CaseIterable, AppEnum {
    case all
    case movies
    case series

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Media")

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {[
        .all: "Movies and Series",
        .movies: "Movies",
        .series: "Series",
    ]}

    var types: [InstanceType] {
        switch self {
        case .all: [.radarr, .sonarr]
        case .movies: [.radarr]
        case .series: [.sonarr]
        }
    }
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

private func addedMessage(_ label: String, alreadyAdded: Bool, search: Bool) -> String {
    switch (alreadyAdded, search) {
    case (false, true): String(localized: "Added \(label) and started searching for releases.")
    case (false, false): String(localized: "Added \(label).")
    case (true, true): String(localized: "\(label) is already in your library. Started searching for releases.")
    case (true, false): String(localized: "\(label) is already in your library.")
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
