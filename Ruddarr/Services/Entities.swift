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
        self.id = Self.identifier(movie.id, instanceId)
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

    static func identifier(_ movieId: Movie.ID, _ instanceId: Instance.ID) -> String {
        "\(instanceId.uuidString):\(movieId)"
    }

    static func parse(_ identifier: String) -> (movieId: Movie.ID, instanceId: Instance.ID)? {
        let parts = identifier.split(separator: ":")

        guard parts.count == 2,
              let instanceId = UUID(uuidString: String(parts[0])),
              let movieId = Movie.ID(parts[1])
        else {
            return nil
        }

        return (movieId, instanceId)
    }

    static func entityIdentifier(_ movie: Movie) -> EntityIdentifier? {
        movie.instanceId.map {
            EntityIdentifier(for: Self.self, identifier: identifier(movie.id, $0))
        }
    }
}

struct MovieEntityQuery: EntityStringQuery {
    func entities(for identifiers: [MovieEntity.ID]) async throws -> [MovieEntity] {
        let instances = await radarrInstances()

        return await withTaskGroup(of: MovieEntity?.self, returning: [MovieEntity].self) { group in
            for identifier in identifiers {
                guard let parsed = MovieEntity.parse(identifier),
                      let instance = instances.first(where: { $0.id == parsed.instanceId })
                else {
                    continue
                }

                group.addTask {
                    let movie = try? await dependencies.api.radarr.movie(parsed.movieId, instance)

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
        self.id = Self.identifier(series.id, instanceId)
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

    static func identifier(_ seriesId: Series.ID, _ instanceId: Instance.ID) -> String {
        "\(instanceId.uuidString):\(seriesId)"
    }

    static func parse(_ identifier: String) -> (seriesId: Series.ID, instanceId: Instance.ID)? {
        let parts = identifier.split(separator: ":")

        guard parts.count == 2,
              let instanceId = UUID(uuidString: String(parts[0])),
              let seriesId = Series.ID(parts[1])
        else {
            return nil
        }

        return (seriesId, instanceId)
    }

    static func entityIdentifier(_ series: Series) -> EntityIdentifier? {
        series.instanceId.map {
            EntityIdentifier(for: Self.self, identifier: identifier(series.id, $0))
        }
    }
}

struct SeriesEntityQuery: EntityStringQuery {
    func entities(for identifiers: [SeriesEntity.ID]) async throws -> [SeriesEntity] {
        let instances = await sonarrInstances()

        return await withTaskGroup(of: SeriesEntity?.self, returning: [SeriesEntity].self) { group in
            for identifier in identifiers {
                guard let parsed = SeriesEntity.parse(identifier),
                      let instance = instances.first(where: { $0.id == parsed.instanceId })
                else {
                    continue
                }

                group.addTask {
                    let series = try? await dependencies.api.sonarr.series(parsed.seriesId, instance)

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
