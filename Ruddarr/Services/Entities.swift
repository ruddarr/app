import Foundation
import AppIntents

struct MovieEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static let defaultQuery = MovieEntityQuery()

    let id: String
    let movieId: Movie.ID
    let instanceId: Instance.ID
    let title: String
    let year: Int

    init(_ movie: Movie, _ instanceId: Instance.ID) {
        self.id = MediaEntityID(movie.id, instanceId).rawValue
        self.movieId = movie.id
        self.instanceId = instanceId
        self.title = movie.title
        self.year = movie.year
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: year > 0 ? "\(String(year))" : nil
        )
    }

    static func entityIdentifier(_ movie: Movie) -> EntityIdentifier? {
        movie.instanceId.map {
            EntityIdentifier(for: Self.self, identifier: MediaEntityID(movie.id, $0).rawValue)
        }
    }
}

struct MovieEntityQuery: EntityStringQuery {
    func entities(for identifiers: [MovieEntity.ID]) async throws -> [MovieEntity] {
        let instances = await radarrInstances()

        return await withTaskGroup(of: MovieEntity?.self, returning: [MovieEntity].self) { group in
            for identifier in identifiers {
                guard let parsed = MediaEntityID(rawValue: identifier),
                      let instance = instances.first(where: { $0.id == parsed.instanceId })
                else {
                    continue
                }

                group.addTask {
                    let movie = try? await dependencies.api.radarr.movie(parsed.mediaId, instance)

                    return movie.map { MovieEntity($0, instance.id) }
                }
            }

            var entities: [MovieEntity] = []

            for await entity in group {
                if let entity { entities.append(entity) }
            }

            return entities
        }
    }

    func entities(matching string: String) async throws -> [MovieEntity] {
        let query = string.trimmed()

        return await library().filter { $0.title.localizedStandardContains(query) }
    }

    func suggestedEntities() async throws -> [MovieEntity] {
        await library().sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func library() async -> [MovieEntity] {
        let instances = await radarrInstances()

        return await withTaskGroup(of: [MovieEntity].self, returning: [MovieEntity].self) { group in
            for instance in instances {
                group.addTask {
                    let movies = (try? await dependencies.api.radarr.fetch(instance)) ?? []

                    return movies.map { MovieEntity($0, instance.id) }
                }
            }

            var entities: [MovieEntity] = []

            for await batch in group {
                entities += batch
            }

            return entities
        }
    }

    @MainActor
    private func radarrInstances() -> [Instance] {
        AppSettings.shared.configuredInstances.filter { $0.type == .radarr }
    }
}

struct SeriesEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Series")
    static let defaultQuery = SeriesEntityQuery()

    let id: String
    let seriesId: Series.ID
    let instanceId: Instance.ID
    let title: String
    let year: Int

    init(_ series: Series, _ instanceId: Instance.ID) {
        self.id = MediaEntityID(series.id, instanceId).rawValue
        self.seriesId = series.id
        self.instanceId = instanceId
        self.title = series.title
        self.year = series.year
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: year > 0 ? "\(String(year))" : nil
        )
    }

    static func entityIdentifier(_ series: Series) -> EntityIdentifier? {
        series.instanceId.map {
            EntityIdentifier(for: Self.self, identifier: MediaEntityID(series.id, $0).rawValue)
        }
    }
}

struct SeriesEntityQuery: EntityStringQuery {
    func entities(for identifiers: [SeriesEntity.ID]) async throws -> [SeriesEntity] {
        let instances = await sonarrInstances()

        return await withTaskGroup(of: SeriesEntity?.self, returning: [SeriesEntity].self) { group in
            for identifier in identifiers {
                guard let parsed = MediaEntityID(rawValue: identifier),
                      let instance = instances.first(where: { $0.id == parsed.instanceId })
                else {
                    continue
                }

                group.addTask {
                    let series = try? await dependencies.api.sonarr.series(parsed.mediaId, instance)

                    return series.map { SeriesEntity($0, instance.id) }
                }
            }

            var entities: [SeriesEntity] = []

            for await entity in group {
                if let entity { entities.append(entity) }
            }

            return entities
        }
    }

    func entities(matching string: String) async throws -> [SeriesEntity] {
        let query = string.trimmed()

        return await library().filter { $0.title.localizedStandardContains(query) }
    }

    func suggestedEntities() async throws -> [SeriesEntity] {
        await library().sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func library() async -> [SeriesEntity] {
        let instances = await sonarrInstances()

        return await withTaskGroup(of: [SeriesEntity].self, returning: [SeriesEntity].self) { group in
            for instance in instances {
                group.addTask {
                    let series = (try? await dependencies.api.sonarr.fetch(instance)) ?? []

                    return series.map { SeriesEntity($0, instance.id) }
                }
            }

            var entities: [SeriesEntity] = []

            for await batch in group {
                entities += batch
            }

            return entities
        }
    }

    @MainActor
    private func sonarrInstances() -> [Instance] {
        AppSettings.shared.configuredInstances.filter { $0.type == .sonarr }
    }
}
