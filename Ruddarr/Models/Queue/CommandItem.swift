import Foundation

struct CommandItem: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let commandName: String
    let status: CommandStatus
    let queued: Date
    let started: Date?
    let ended: Date?
    let message: String?
    let trigger: CommandTrigger

    var instanceId: Instance.ID?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case commandName
        case status
        case queued
        case started
        case ended
        case message
        case trigger
    }

    static func == (lhs: CommandItem, rhs: CommandItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.instanceId == rhs.instanceId &&
        lhs.status == rhs.status &&
        lhs.message == rhs.message
    }

    var titleLabel: String {
        commandName
    }

    var statusLabel: String {
        switch status {
        case .queued: String(localized: "Queued", comment: "State of running command")
        case .started: String(localized: "Running", comment: "State of running command")
        case .completed: String(localized: "Completed", comment: "State of running command")
        case .failed: String(localized: "Failed", comment: "State of running command")
        case .cancelled: String(localized: "Cancelled", comment: "State of running command")
        case .aborted: String(localized: "Aborted", comment: "State of running command")
        }
    }

    var triggerLabel: String {
        switch trigger {
        case .manual: String(localized: "Manual", comment: "Command trigger type")
        case .scheduled: String(localized: "Scheduled", comment: "Command trigger type")
        }
    }

    var isActive: Bool {
        status == .queued || status == .started
    }
}

enum CommandStatus: String, Codable {
    case queued
    case started
    case completed
    case failed
    case cancelled
    case aborted
}

enum CommandTrigger: String, Codable {
    case manual
    case scheduled
}
