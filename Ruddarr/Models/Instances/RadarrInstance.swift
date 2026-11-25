import Sentry
import Foundation

@MainActor
@Observable
class RadarrInstance {
    private var instance: Instance

    var isVoid = true

    var movies: Movies
    var lookup: MovieLookup
    var releases: MovieReleases
    var metadata: MovieMetadata

    var customFilters: [CustomFilter]?

    init(_ instance: Instance = .radarrVoid) {
        if instance.type != .radarr {
            fatalError("\(instance.type.rawValue) given to RadarrInstance")
        }

        self.isVoid = instance == .radarrVoid

        self.instance = instance
        self.movies = Movies(instance)
        self.lookup = MovieLookup(instance)
        self.releases = MovieReleases(instance)
        self.metadata = MovieMetadata(instance)
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .radarrVoid

        self.instance = target
        self.movies = Movies(target)
        self.lookup = MovieLookup(target)
        self.releases = MovieReleases(target)
        self.metadata = MovieMetadata(target)
        self.customFilters = nil
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

        async let rootFolders = dependencies.api.instance.rootFolders(instance)
        async let qualityProfiles = dependencies.api.instance.qualityProfiles(instance)
        async let tags = dependencies.api.instance.tags(instance)
        async let filters = fetchCustomFilters()

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

        customFilters = await filters

        guard updated else { return nil }

        if !movies.items.isEmpty {
            instance.stats = await InstanceStats.make(movies: movies.items)
        }

        return instance
    }

    private func fetchCustomFilters() async -> [CustomFilter]? {
        do {
            return try await dependencies.api.instance.customFilters(instance)
                .filter { $0.type == Movie.customFilterType && $0.isSupported(for: Movie.self) }
        } catch is CancellationError {
            return customFilters
        } catch {
            leaveBreadcrumb(.error, category: "instance.metadata", message: "Custom filters fetch failed", data: ["error": error])
            return customFilters
        }
    }
}
