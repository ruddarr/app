import Foundation
import SwiftUI

struct InstanceCommandStatus: Identifiable, Codable, Equatable, Hashable {
    let commandId: Int
    let name: String
    let commandName: String?
    var message: String?
    var status: String
    var result: String?
    let queued: Date
    var started: Date?
    var ended: Date?
    let trigger: String?

    var instanceId: Instance.ID?
    var subject: String?

    enum CodingKeys: String, CodingKey {
        case commandId = "id"
        case name, commandName, message, status, result
        case queued, started, ended, trigger
    }

    var id: String {
        "\(instanceId?.uuidString ?? "none")-\(commandId)"
    }

    var state: CommandStatusState {
        CommandStatusState(rawValue: status) ?? .unknown
    }

    var isTerminal: Bool {
        switch state {
        case .completed, .failed, .aborted, .cancelled, .orphaned:
            return true
        case .queued, .started, .unknown:
            return false
        }
    }

    var isSearchCommand: Bool {
        Self.searchCommandNames.contains(name)
    }

    static let searchCommandNames: Set<String> = [
        "MoviesSearch",
        "SeriesSearch",
        "SeasonSearch",
        "EpisodeSearch",
    ]

    static let visibleCommandNames: Set<String> = [
        "MoviesSearch",
        "MissingMoviesSearch",
        "CutoffUnmetMoviesSearch",
        "EpisodeSearch",
        "SeasonSearch",
        "SeriesSearch",
        "MissingEpisodeSearch",
        "CutoffUnmetEpisodeSearch",
        "RefreshMovie",
        "RefreshSeries",
        "RefreshCollections",
        "RssSync",
        "ManualImport",
        "RenameFiles",
        "RenameMovie",
        "RenameSeries",
        "RescanMovie",
        "RescanSeries",
    ]

    var sortDate: Date {
        started ?? queued
    }

    var displayTitle: String {
        subject ?? commandName ?? name
    }
}

enum CommandStatusState: String, Codable {
    case queued
    case started
    case completed
    case failed
    case aborted
    case cancelled
    case orphaned
    case unknown

    var label: String {
        switch self {
        case .queued: String(localized: "Queued", comment: "Command status")
        case .started: String(localized: "Running", comment: "Command status")
        case .completed: String(localized: "Completed", comment: "Command status")
        case .failed: String(localized: "Failed", comment: "Command status")
        case .aborted: String(localized: "Aborted", comment: "Command status")
        case .cancelled: String(localized: "Cancelled", comment: "Command status")
        case .orphaned: String(localized: "Orphaned", comment: "Command status")
        case .unknown: String(localized: "Unknown", comment: "Command status")
        }
    }

    var systemImage: String {
        switch self {
        case .queued: "clock"
        case .started: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle"
        case .failed, .aborted, .orphaned: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .completed: .green
        case .failed, .aborted, .orphaned: .red
        case .cancelled: .secondary
        case .queued, .started: .accentColor
        case .unknown: .secondary
        }
    }
}

@MainActor
@Observable
class Commands {
    static let shared = Commands()

    private var timer: Timer?

    var error: API.Error?

    var isLoading: Bool = false
    var performRefresh: Bool = false

    var instances: [Instance] = []
    var items: [Instance.ID: [InstanceCommandStatus]] = [:]

    private let perInstanceLimit = 50

    private init() {
        let interval: TimeInterval = isRunningIn(.preview) ? 30 : 5

        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                if await self.performRefresh {
                    await self.fetchAll()
                }
            }
        }
    }

    func track(_ status: InstanceCommandStatus) {
        guard let instanceId = status.instanceId else { return }
        var list = items[instanceId] ?? []
        list.removeAll { $0.id == status.id }
        list.insert(status, at: 0)
        items[instanceId] = Array(list.prefix(perInstanceLimit))
    }

    func merge(_ incoming: [InstanceCommandStatus], for instanceId: Instance.ID) {
        let visible = incoming.filter { InstanceCommandStatus.visibleCommandNames.contains($0.name) }
        var existing = items[instanceId] ?? []
        let existingById = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for var fresh in visible {
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

    func fetchAll() async {
        guard !isLoading else { return }

        error = nil
        isLoading = true

        for instance in instances {
            do {
                let statuses = try await dependencies.api.fetchCommands(instance)
                merge(statuses, for: instance.id)
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "commands", message: "Fetch failed", data: ["error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }
        }

        isLoading = false
    }

    func filteredItems(showAll: Bool) -> [InstanceCommandStatus] {
        let all = items.values.flatMap { $0 }
            .filter { InstanceCommandStatus.visibleCommandNames.contains($0.name) }
            .filter { !$0.isTerminal || ($0.ended ?? $0.started ?? $0.queued) >= Date().addingTimeInterval(-300) }
        let filtered = showAll ? all : all.filter { $0.isSearchCommand }
        return filtered.sorted { $0.sortDate > $1.sortDate }
    }
}
