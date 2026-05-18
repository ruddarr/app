import os
import SwiftUI
import Foundation

@MainActor
@Observable
class ProwlarrInstance {
    private let instance: Instance

    var indexers: [Indexer] = []
    var isLoading: Bool = false
    var error: API.Error?

    init(_ instance: Instance) {
        if instance.type != .prowlarr {
            fatalError("\(instance.type.rawValue) given to ProwlarrInstance")
        }
        self.instance = instance
    }

    func fetchIndexers() async {
        isLoading = true
        error = nil

        do {
            indexers = try await dependencies.api.fetchIndexers(instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError
            leaveBreadcrumb(.error, category: "prowlarr.indexers", message: "Fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isLoading = false
    }

    func setEnabled(_ id: Int, _ enable: Bool) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.setIndexersEnabled([id], enable, instance)
            return true
        } catch is CancellationError {
            return true // optimistic UI already applied; treat cancellation as success
        } catch let apiError as API.Error {
            error = apiError
            leaveBreadcrumb(.error, category: "prowlarr.indexers", message: "Toggle failed", data: ["error": apiError, "id": id])
            return false
        } catch {
            self.error = API.Error(from: error)
            leaveBreadcrumb(.error, category: "prowlarr.indexers", message: "Toggle failed", data: ["error": error, "id": id])
            return false
        }
    }
}
