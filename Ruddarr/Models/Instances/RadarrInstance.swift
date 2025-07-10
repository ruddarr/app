import os
import SwiftUI
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
    }

    var id: UUID {
        instance.id
    }

    var isSlow: Bool {
        instance.mode.isSlow
    }

    var rootFolders: [InstanceRootFolders] {
        instance.rootFolders
    }

    var qualityProfiles: [InstanceQualityProfile] {
        instance.qualityProfiles
    }
    
    var tags: [InstanceTags] {
        instance.tags
    }

    func fetchMetadata() async -> Instance? {
        if isVoid {
            return nil
        }

        do {
            async let rootFolders = dependencies.api.rootFolders(instance)
            async let qualityProfiles = dependencies.api.qualityProfiles(instance)
            async let tags = dependencies.api.getTags(instance)

            instance.rootFolders = try await rootFolders
            instance.qualityProfiles = try await qualityProfiles
            instance.tags = try await tags
        } catch {
            return nil
        }

        return instance
    }
}
