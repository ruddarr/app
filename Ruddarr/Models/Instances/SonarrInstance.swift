import Sentry
import Foundation

@MainActor
@Observable
class SonarrInstance {
    private var instance: Instance

    var isVoid = true

    var series: SeriesModel
    var lookup: SeriesLookup
    var releases: SeriesReleases
    var episodes: SeriesEpisodes
    var files: SeriesFiles

    init(_ instance: Instance = .sonarrVoid) {
        if instance.type != .sonarr {
            fatalError("\(instance.type.rawValue) given to SonarrInstance")
        }

        self.isVoid = instance == .sonarrVoid

        self.instance = instance
        self.series = SeriesModel(instance)
        self.lookup = SeriesLookup(instance)
        self.releases = SeriesReleases(instance)
        self.episodes = SeriesEpisodes(instance)
        self.files = SeriesFiles(instance)
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .sonarrVoid

        self.instance = target
        self.series = SeriesModel(target)
        self.lookup = SeriesLookup(target)
        self.releases = SeriesReleases(target)
        self.episodes = SeriesEpisodes(instance)
        self.files = SeriesFiles(instance)
    }

    var id: UUID {
        instance.id
    }

    var isSlow: Bool {
        instance.mode.isSlow
    }

    var rootFolders: [InstanceRootFolder] {
        instance.rootFolders
    }

    var qualityProfiles: [InstanceQualityProfile] {
        instance.qualityProfiles
    }

    var tags: [Tag] {
        instance.tags
    }

    func fetchMetadata() async -> Instance? {
        if isVoid {
            return nil
        }

        async let rootFolders = dependencies.api.rootFolders(instance)
        async let qualityProfiles = dependencies.api.qualityProfiles(instance)
        async let tags = dependencies.api.getTags(instance)

        var updated = false

        do {
            instance.rootFolders = try await rootFolders
            updated = true
        } catch is CancellationError {
            return nil
        } catch {
            leaveBreadcrumb(.error, category: "instance.metadata", message: "Root folders fetch failed", data: ["error": error])
        }

        do {
            instance.qualityProfiles = try await qualityProfiles
            updated = true
        } catch is CancellationError {
            return nil
        } catch {
            leaveBreadcrumb(.error, category: "instance.metadata", message: "Quality profiles fetch failed", data: ["error": error])
        }

        do {
            instance.tags = try await tags
            updated = true
        } catch is CancellationError {
            return nil
        } catch {
            leaveBreadcrumb(.error, category: "instance.metadata", message: "Tags fetch failed", data: ["error": error])
        }

        guard updated else { return nil }

        if !series.items.isEmpty {
            instance.stats = await InstanceStats.make(series: series.items)
        }

        return instance
    }
}
