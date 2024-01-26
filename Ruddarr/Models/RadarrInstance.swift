import os
import Foundation

@Observable class RadarrInstance {
    private var instance: Instance

    var movies: Movies
    var lookup: MovieLookup

    init(_ instance: Instance = .void) {
        if instance.type != .radarr {
            fatalError("\(instance.type.rawValue) given to RadarrInstance")
        }

        self.instance = instance
        self.movies = Movies(instance)
        self.lookup = MovieLookup(instance)
    }

    var void: Bool {
        instance == .void
    }

    var rootFolders: [InstanceRootFolders] {
        instance.rootFolders
    }

    var qualityProfiles: [InstanceQualityProfile] {
        return instance.qualityProfiles
    }

    func switchTo(_ target: Instance) {
        instance = target
        movies = Movies(target)
        lookup = MovieLookup(target)
    }

    func fetchMetadata() async throws -> Instance? {
        if void {
            return nil
        }

        instance.rootFolders = try await dependencies.api.rootFolders(instance)
        instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

        return instance
    }
}
