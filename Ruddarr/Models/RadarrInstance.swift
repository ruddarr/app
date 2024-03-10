import os
import SwiftUI
import Foundation


@Observable class RadarrInstance {
    private var instance: Instance

    var isVoid = true
    var movies: Movies {
        didSet {
            dependencies.notificationCenter.post(name: .moviesChanged, object: self)
        }
    }
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

    var id: UUID {
        instance.id
    }

    var rootFolders: [InstanceRootFolders] {
        instance.rootFolders
    }

    var qualityProfiles: [InstanceQualityProfile] {
        instance.qualityProfiles
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .void
        instance = target
        movies.items.removeAll()
        movies = Movies(target)
        lookup = MovieLookup(target)
        releases = MovieReleases(target)
    }

    func fetchMetadata() async -> Instance? {
        if isVoid {
            return nil
        }

        do {
            instance.rootFolders = try await dependencies.api.rootFolders(instance)
            instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)
        } catch is CancellationError {
            return nil
        } catch let urlError as URLError where urlError.code == .cancelled {
            return nil
        } catch {
            return nil
        }

        return instance
    }
}
