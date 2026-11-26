import Foundation
import AppIntents
import CoreTransferable
import UniformTypeIdentifiers

struct SeriesEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Series")
    static let defaultQuery = SeriesEntityQuery()

    let id: String
    let seriesId: Series.ID
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

    @Property(title: "Network")
    var network: String?

    @Property(title: "Seasons")
    var seasons: Int?

    @Property(title: "Episodes")
    var episodes: Int?

    @Property(title: "Size on Disk")
    var sizeOnDisk: Measurement<UnitInformationStorage>?

    @Property(title: "Next Airing")
    var nextAiring: Date?

    @Property(title: "Previous Airing")
    var previousAiring: Date?

    @Property(title: "Instance")
    var instance: String

    init(_ series: Series, _ instance: Instance) {
        self.id = MediaEntityID(series.id, instance.id).rawValue
        self.seriesId = series.id
        self.instanceId = instance.id
        self.overview = series.overview
        self.title = series.title
        self.year = series.year
        self.status = series.status.label
        self.monitored = series.monitored
        self.network = series.network
        self.seasons = series.statistics?.seasonCount
        self.episodes = series.statistics?.episodeCount
        self.sizeOnDisk = series.statistics.map { Measurement(value: Double($0.sizeOnDisk), unit: .bytes) }
        self.nextAiring = series.nextAiring
        self.previousAiring = series.previousAiring
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

    var summary: String {
        let heading = year > 0 ? "\(title) (\(year))" : title

        guard let overview, !overview.isEmpty else {
            return heading
        }

        return "\(heading)\n\n\(overview)"
    }
}

extension SeriesEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { Data($0.summary.utf8) }
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
