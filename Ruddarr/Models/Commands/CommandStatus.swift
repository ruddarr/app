import Foundation

struct InstanceCommandStatus: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let commandName: String?
    var message: String?
    var status: String
    var result: String?
    let queued: Date
    var started: Date?
    var ended: Date?
    let trigger: String?

    /// Stamped client-side after decoding so we can group + filter per instance.
    var instanceId: Instance.ID?

    /// Stamped client-side at dispatch time with a human-readable subject
    /// (e.g. "Breaking Bad — Season 2") so the list row can show something
    /// richer than the raw command name.
    var subject: String?

    enum CodingKeys: String, CodingKey {
        case id, name, commandName, message, status, result
        case queued, started, ended, trigger
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

    /// Sort key: most recent first. Uses `started` if available, otherwise `queued`.
    var sortDate: Date {
        started ?? queued
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
}
