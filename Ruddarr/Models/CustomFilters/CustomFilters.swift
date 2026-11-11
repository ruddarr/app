import Foundation
import Sentry

/// The custom filters of one instance's Movies or Series grid: the ones saved in the app and the ones on the server.
///
/// Both lists are cached per instance and `type` in `dependencies.store`, and loaded in `init`,
/// so a selected filter applies on a cold launch before (or without) a network round trip.
@MainActor
@Observable
final class CustomFilters {
    private let instance: Instance
    private let type: String

    /// Filters saved in the app for this instance, sorted by label.
    private(set) var appFilters: [CustomFilter] = []
    /// Filters saved on the server with this grid's `type`, as last fetched (cached for offline use), sorted by label.
    private(set) var serverFilters: [CustomFilter] = []

    var error: API.Error?
    var isWorking: Bool = false

    /// `type` is the server's custom filter type, e.g. `Movie.customFilterType`.
    init(_ instance: Instance, type: String) {
        self.instance = instance
        self.type = type

        guard !isVoid, let data = dependencies.store.data(forKey: storeKey) else { return }

        do {
            let cache = try JSONDecoder().decode(Cache.self, from: data)
            appFilters = Self.sorted(cache.app)
            serverFilters = Self.sorted(cache.server)
        } catch {
            leaveBreadcrumb(.warning, category: "custom.filters", message: "Cache decode failed", data: ["error": error])
        }
    }

    /// Server filters first, then app filters, each sorted by label.
    var all: [CustomFilter] {
        serverFilters + appFilters
    }

    func byId(_ id: CustomFilter.ID?) -> CustomFilter? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// Fetches the server's filters of this grid's `type`.
    /// Background fetches only leave a breadcrumb when they fail, so they don't set `error`.
    func fetch(reportingErrors: Bool = false) async -> Bool {
        guard !isVoid else { return true }

        return await request("fetch", reportingErrors: reportingErrors) {
            let resources = try await dependencies.api.instance.customFilters(instance)
            serverFilters = Self.sorted(resources.filter { $0.type == type }.compactMap(\.customFilter))
            persist()
        }
    }

    /// Saves `filter` on the server when `onServer` is true, otherwise in the app.
    /// Moving a filter between the two deletes the old copy. Returns the saved filter, whose `id` changes when it moves.
    func save(_ filter: CustomFilter, onServer: Bool) async -> CustomFilter? {
        var saved: CustomFilter?
        let resource = CustomFilterResource(filter, type: type)

        let success = await request("save") {
            switch (filter.id, onServer) {
            case (.app, false):
                saved = filter
            case (.app, true):
                let created = try await dependencies.api.instance.createCustomFilter(resource, instance)
                guard let result = created.customFilter else {
                    throw API.Error(from: AppError("The server didn't return the saved filter's id."))
                }

                appFilters.removeAll { $0.id == filter.id }
                saved = result
            case (.server, true):
                let updated = try await dependencies.api.instance.updateCustomFilter(resource, instance)
                saved = updated.customFilter ?? filter
            case (.server, false):
                _ = try await dependencies.api.instance.deleteCustomFilter(resource, instance)
                serverFilters.removeAll { $0.id == filter.id }
                saved = CustomFilter(id: .app(UUID()), label: filter.label, conditions: filter.conditions)
            }

            if let saved {
                upsert(saved)
            }

            persist()
        }

        return success ? saved : nil
    }

    /// Deletes `filter` from the server or the app.
    func delete(_ filter: CustomFilter) async -> Bool {
        await request("delete") {
            if filter.isOnServer {
                _ = try await dependencies.api.instance.deleteCustomFilter(CustomFilterResource(filter, type: type), instance)
                serverFilters.removeAll { $0.id == filter.id }
            } else {
                appFilters.removeAll { $0.id == filter.id }
            }

            persist()
        }
    }

    private var isVoid: Bool {
        instance.id == Instance.radarrVoid.id || instance.id == Instance.sonarrVoid.id
    }

    private var storeKey: String {
        "customFilters:\(instance.id.uuidString):\(type)"
    }

    private func request(_ operation: String, reportingErrors: Bool = true, _ perform: () async throws -> Void) async -> Bool {
        if reportingErrors {
            error = nil
        }

        isWorking = true

        var failure: API.Error?

        do {
            try await perform()
        } catch is CancellationError {
            // do nothing
        } catch {
            let apiError = error as? API.Error ?? API.Error(from: error)
            failure = apiError

            leaveBreadcrumb(.error, category: "custom.filters", message: "Request failed", data: ["operation": operation, "error": apiError])
        }

        if reportingErrors {
            error = failure
        }

        isWorking = false

        return failure == nil
    }

    private func upsert(_ filter: CustomFilter) {
        if filter.isOnServer {
            Self.upsert(filter, into: &serverFilters)
            serverFilters = Self.sorted(serverFilters)
        } else {
            Self.upsert(filter, into: &appFilters)
            appFilters = Self.sorted(appFilters)
        }
    }

    private static func upsert(_ filter: CustomFilter, into filters: inout [CustomFilter]) {
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index] = filter
        } else {
            filters.append(filter)
        }
    }

    private func persist() {
        guard !isVoid else { return }

        do {
            let data = try JSONEncoder().encode(Cache(app: appFilters, server: serverFilters))
            dependencies.store.set(data, forKey: storeKey)
        } catch {
            leaveBreadcrumb(.error, category: "custom.filters", message: "Cache encode failed", data: ["error": error])
        }
    }

    private static func sorted(_ filters: [CustomFilter]) -> [CustomFilter] {
        filters.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    private struct Cache: Codable {
        var app: [CustomFilter]
        var server: [CustomFilter]
    }
}
