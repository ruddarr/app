import Foundation
import AppIntents
import CoreTransferable
import UniformTypeIdentifiers

struct MovieEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static let defaultQuery = MovieEntityQuery()

    let id: String
    let movieId: Movie.ID
    let instanceId: Instance.ID
    let overview: String?

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

    @Property(title: "Instance")
    var instance: String

    init(_ movie: Movie, _ instance: Instance) {
        self.id = MediaEntityID(movie.id, instance.id).rawValue
        self.movieId = movie.id
        self.instanceId = instance.id
        self.overview = movie.overview
        self.title = movie.title
        self.year = movie.year
        self.status = movie.status.label
        self.monitored = movie.monitored
        self.downloaded = movie.isDownloaded
        self.sizeOnDisk = movie.sizeOnDisk.map { Measurement(value: Double($0), unit: .bytes) }
        self.inCinemas = movie.inCinemas
        self.digitalRelease = movie.digitalRelease
        self.physicalRelease = movie.physicalRelease
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

    var summary: String {
        let heading = year > 0 ? "\(title) (\(year))" : title

        guard let overview, !overview.isEmpty else {
            return heading
        }

        return "\(heading)\n\n\(overview)"
    }
}

extension MovieEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { Data($0.summary.utf8) }
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
