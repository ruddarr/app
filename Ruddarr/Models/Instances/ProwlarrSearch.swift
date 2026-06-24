import os
import SwiftUI

@MainActor
@Observable
class ProwlarrSearch {
    private let instance: Instance

    var query: String = ""
    var category: ProwlarrSearchCategory = .all

    var items: [ProwlarrRelease] = []
    var isSearching: Bool = false
    var hasSearched: Bool = false
    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var protocols: [String] = []
    var indexers: [String] = []

    func reset() {
        items = []
        hasSearched = false
        error = nil
        setFilterData()
    }

    func setFilterData() {
        var seenProtocols: Set<String> = []
        protocols = items.map { $0.network.label }.filter { seenProtocols.insert($0).inserted }

        var seenIndexers: Set<String> = []
        indexers = items
            .map { $0.indexerLabel }
            .filter { seenIndexers.insert($0).inserted }
            .sorted()
    }

    init(_ instance: Instance) {
        if instance.type != .prowlarr {
            fatalError("\(instance.type.rawValue) given to ProwlarrSearch")
        }
        self.instance = instance
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items = []
        error = nil
        isSearching = true
        setFilterData()

        do {
            let results = try await dependencies.api.searchProwlarr(trimmed, category.categoryIds, instance)
            try Task.checkCancellation()
            items = results
            setFilterData()
            hasSearched = true
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError
            hasSearched = true
            leaveBreadcrumb(.error, category: "prowlarr.search", message: "Search failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
            hasSearched = true
        }

        isSearching = false
    }

    func grab(_ release: ProwlarrRelease) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.grabProwlarrRelease(release.guid, release.indexerId, instance)
            return true
        } catch is CancellationError {
            return false
        } catch let apiError as API.Error {
            error = apiError
            leaveBreadcrumb(.error, category: "prowlarr.search", message: "Grab failed", data: ["error": apiError, "guid": release.guid])
            return false
        } catch {
            self.error = API.Error(from: error)
            leaveBreadcrumb(.error, category: "prowlarr.search", message: "Grab failed", data: ["error": error, "guid": release.guid])
            return false
        }
    }
}
