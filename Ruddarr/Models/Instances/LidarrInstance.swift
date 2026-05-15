import os
import SwiftUI
import Foundation

@MainActor
@Observable
class LidarrInstance {
    private var instance: Instance

    var isVoid = true

    var artists: ArtistModel
    var albums: AlbumModel
    var lookup: ArtistLookup
    var releases: ArtistReleases
    var files: ArtistFiles

    init(_ instance: Instance = .lidarrVoid) {
        if instance.type != .lidarr {
            fatalError("\(instance.type.rawValue) given to LidarrInstance")
        }

        self.isVoid = instance == .lidarrVoid

        self.instance = instance
        self.artists = ArtistModel(instance)
        self.albums = AlbumModel(instance)
        self.lookup = ArtistLookup(instance)
        self.releases = ArtistReleases(instance)
        self.files = ArtistFiles(instance)
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .lidarrVoid

        self.instance = target
        self.artists = ArtistModel(target)
        self.albums = AlbumModel(target)
        self.lookup = ArtistLookup(target)
        self.releases = ArtistReleases(target)
        self.files = ArtistFiles(target)
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

    var metadataProfiles: [InstanceMetadataProfile] {
        instance.metadataProfiles
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
            async let metadataProfiles = dependencies.api.metadataProfiles(instance)
            async let tags = dependencies.api.getTags(instance)

            instance.rootFolders = try await rootFolders
            instance.qualityProfiles = try await qualityProfiles
            instance.metadataProfiles = try await metadataProfiles
            instance.tags = try await tags
        } catch {
            return nil
        }

        return instance
    }
}
