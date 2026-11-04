import Foundation
import AppIntents

struct MovieEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static let defaultQuery = MovieEntityQuery()

    let id: String
    let movieId: Movie.ID
    let instanceId: Instance.ID

    @Property(title: "Title")
    var title: String

    @Property(title: "Year")
    var year: Int

    @Property(title: "Status")
    var status: String

    @Property(title: "Monitored")
    var monitored: Bool

    @Property(title: "Downloaded")
    var downloaded: Bool

    @Property(title: "Size on Disk")
    var sizeOnDisk: Measurement<UnitInformationStorage>?

    @Property(title: "In Cinemas")
    var inCinemas: Date?

    @Property(title: "Digital Release")
    var digitalRelease: Date?

    @Property(title: "Physical Release")
    var physicalRelease: Date?

    @Property(title: "IMDb ID")
    var imdbId: String?

    @Property(title: "TMDB ID")
    var tmdbId: Int

    @Property(title: "Instance")
    var instance: String

    init(_ movie: Movie, _ instance: Instance) {
        self.id = MediaEntityID(movie.id, instance.id).rawValue
        self.movieId = movie.id
        self.instanceId = instance.id
        self.title = movie.title
        self.year = movie.year
        self.status = movie.status.label
        self.monitored = movie.monitored
        self.downloaded = movie.isDownloaded
        self.sizeOnDisk = movie.sizeOnDisk.map { Measurement(value: Double($0), unit: .bytes) }
        self.inCinemas = movie.inCinemas
        self.digitalRelease = movie.digitalRelease
        self.physicalRelease = movie.physicalRelease
        self.imdbId = movie.imdbId
        self.tmdbId = movie.tmdbId
        self.instance = instance.label
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

                    return movie.map { MovieEntity($0, instance) }
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

                    return movies.map { MovieEntity($0, instance) }
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

struct SeriesEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Series")
    static let defaultQuery = SeriesEntityQuery()

    let id: String
    let seriesId: Series.ID
    let instanceId: Instance.ID

    @Property(title: "Title")
    var title: String

    @Property(title: "Year")
    var year: Int

    @Property(title: "Status")
    var status: String

    @Property(title: "Monitored")
    var monitored: Bool

    @Property(title: "Network")
    var network: String?

    @Property(title: "Seasons")
    var seasons: Int?

    @Property(title: "Episodes")
    var episodes: Int?

    @Property(title: "Downloaded Episodes")
    var downloadedEpisodes: Int?

    @Property(title: "Size on Disk")
    var sizeOnDisk: Measurement<UnitInformationStorage>?

    @Property(title: "Next Airing")
    var nextAiring: Date?

    @Property(title: "Previous Airing")
    var previousAiring: Date?

    @Property(title: "IMDb ID")
    var imdbId: String?

    @Property(title: "TVDB ID")
    var tvdbId: Int

    @Property(title: "Instance")
    var instance: String

    init(_ series: Series, _ instance: Instance) {
        self.id = MediaEntityID(series.id, instance.id).rawValue
        self.seriesId = series.id
        self.instanceId = instance.id
        self.title = series.title
        self.year = series.year
        self.status = series.status.label
        self.monitored = series.monitored
        self.network = series.network
        self.seasons = series.statistics?.seasonCount
        self.episodes = series.statistics?.episodeCount
        self.downloadedEpisodes = series.statistics?.episodeFileCount
        self.sizeOnDisk = series.statistics.map { Measurement(value: Double($0.sizeOnDisk), unit: .bytes) }
        self.nextAiring = series.nextAiring
        self.previousAiring = series.previousAiring
        self.imdbId = series.imdbId
        self.tvdbId = series.tvdbId
        self.instance = instance.label
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

                    return series.map { SeriesEntity($0, instance) }
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

                    return series.map { SeriesEntity($0, instance) }
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
