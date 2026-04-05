import Foundation

@MainActor
@Observable
final class Commands {
    static let shared = Commands()

    private var timer: Timer?

    var error: API.Error?
    var isLoading: Bool = false
    var performRefresh: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [InstanceCommandStatus]] = [:]

    /// Max items to keep per instance. The instance also trims its own
    /// history, but we cap locally so long-running sessions don't grow forever.
    private let perInstanceLimit = 50

    init() {
        let interval: TimeInterval = isRunningIn(.preview) ? 30 : 5
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                guard self.performRefresh else { return }
                await self.refreshActive()
            }
        }
    }

    /// Test-only factory that skips timer scheduling.
    static func makeForTesting() -> Commands {
        let c = Commands()
        c.timer?.invalidate()
        c.timer = nil
        return c
    }

    /// Called from `dispatchSearch` call sites immediately after a command POST
    /// so the user sees the new row without waiting for the next poll.
    func track(_ status: InstanceCommandStatus) {
        guard let instanceId = status.instanceId else { return }
        var list = items[instanceId] ?? []
        list.removeAll { $0.id == status.id }
        list.insert(status, at: 0)
        items[instanceId] = Array(list.prefix(perInstanceLimit))
    }

    /// Merges a fresh list of statuses fetched from the instance. Existing
    /// entries are updated in place (preserving client-side `subject`),
    /// unknown entries are inserted, and anything not seen since the last
    /// `fetchAll` is left alone (the instance may have trimmed them).
    func merge(_ incoming: [InstanceCommandStatus], for instanceId: Instance.ID) {
        var existing = items[instanceId] ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for var fresh in incoming {
            if let prior = existingById[fresh.id], fresh.subject == nil {
                fresh.subject = prior.subject
            }
            if let idx = existing.firstIndex(where: { $0.id == fresh.id }) {
                existing[idx] = fresh
            } else {
                existing.append(fresh)
            }
        }

        existing.sort { $0.sortDate > $1.sortDate }
        items[instanceId] = Array(existing.prefix(perInstanceLimit))
    }

    /// Initial population + pull-to-refresh.
    func fetchAll() async {
        guard !isLoading else { return }
        error = nil
        isLoading = true

        for instance in instances {
            do {
                let statuses = try await dependencies.api.fetchCommands(instance)
                merge(statuses, for: instance.id)
            } catch is CancellationError {
                // ignore
            } catch let apiError as API.Error {
                error = apiError
                leaveBreadcrumb(.error, category: "commands", message: "Fetch failed", data: ["error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }
        }

        isLoading = false
    }

    /// Called by the polling timer. Only re-fetches commands that are still
    /// non-terminal, to minimize API traffic.
    func refreshActive() async {
        for instance in instances {
            guard let list = items[instance.id] else { continue }
            let active = list.filter { !$0.isTerminal }
            for command in active {
                do {
                    let updated = try await dependencies.api.fetchCommand(command.id, instance)
                    merge([updated], for: instance.id)
                } catch is CancellationError {
                    // ignore
                } catch {
                    leaveBreadcrumb(.warning, category: "commands", message: "Poll failed",
                                    data: ["id": command.id, "error": error])
                }
            }
        }
    }

    /// Returns a flat, sorted list across all instances, respecting the
    /// search-only default filter.
    func filteredItems(showAll: Bool) -> [InstanceCommandStatus] {
        let all = items.values.flatMap { $0 }
        let filtered = showAll ? all : all.filter { $0.isSearchCommand }
        return filtered.sorted { $0.sortDate > $1.sortDate }
    }
}
