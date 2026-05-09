import os
import SwiftUI
import Foundation

@MainActor
@Observable
class LidarrInstance {
    private var instance: Instance

    var isVoid = true

    var artists: Artists
//    var lookup: ArtistLookup
//    var releases: ArtistReleases
//    var metadata: MovieMetadata

    init(_ instance: Instance = .lidarrVoid) {
        if instance.type != .lidarr {
            fatalError("\(instance.type.rawValue) given to LidarrInstance")
        }

        self.isVoid = instance == .lidarrVoid

        self.instance = instance
        self.artists = Artists(instance)
//        self.lookup = MovieLookup(instance)
//        self.releases = MovieReleases(instance)
//        self.metadata = MovieMetadata(instance)
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .lidarrVoid

        self.instance = target
        self.artists = Artists(target)
//        self.lookup = MovieLookup(target)
//        self.releases = MovieReleases(target)
//        self.metadata = MovieMetadata(target)
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
