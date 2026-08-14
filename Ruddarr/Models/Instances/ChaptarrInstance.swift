import Foundation
import Sentry

@MainActor
@Observable
class ChaptarrInstance {
    private var instance: Instance

    var isVoid = true

    var books: Books
    var lookup: BookLookup
    var metadata: BookMetadata

    init(_ instance: Instance = .chaptarrVoid) {
        if instance.type != .chaptarr {
            fatalError("\(instance.type.rawValue) given to ChaptarrInstance")
        }

        self.isVoid = instance == .chaptarrVoid

        self.instance = instance
        self.books = Books(instance)
        self.lookup = BookLookup(instance)
        self.metadata = BookMetadata(instance)
    }

    func switchTo(_ target: Instance) {
        isVoid = target == .chaptarrVoid

        self.instance = target
        self.books = Books(target)
        self.lookup = BookLookup(target)
        self.metadata = BookMetadata(target)
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

        async let rootFolders = dependencies.api.rootFolders(instance)
        async let qualityProfiles = dependencies.api.qualityProfiles(instance)
        async let metadataProfiles = dependencies.api.metadataProfiles(instance)
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
            instance.metadataProfiles = try await metadataProfiles
            updated = true
        } catch is CancellationError {
            return nil
        } catch {
            leaveBreadcrumb(.error, category: "instance.metadata", message: "Metadata profiles fetch failed", data: ["error": error])
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

        return instance
    }
}
