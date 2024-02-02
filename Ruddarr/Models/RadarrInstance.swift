import os
import SwiftUI
import Foundation

@Observable class RadarrInstance {
    private var instance: Instance

    var isVoid = true
    var movies: Movies
    var lookup: MovieLookup
    var releases: MovieReleases

    init(_ instance: Instance = .void) {
        if instance.type != .radarr {
            fatalError("\(instance.type.rawValue) given to RadarrInstance")
        }

        self.isVoid = instance == .void

        self.instance = instance
        self.movies = Movies(instance)
        self.lookup = MovieLookup(instance)
        self.releases = MovieReleases(instance)
    }

    var rootFolders: [InstanceRootFolders] {
        instance.rootFolders
    }

    var qualityProfiles: [InstanceQualityProfile] {
        return instance.qualityProfiles
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .void
        instance = target
        movies.items.removeAll()
        movies = Movies(target)
        lookup = MovieLookup(target)
        releases = MovieReleases(target)
    }

    func fetchMetadata() async throws -> Instance? {
        if isVoid {
            return nil
        }

        instance.rootFolders = try await dependencies.api.rootFolders(instance)
        instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

        return instance
    }
}
