import Foundation

extension Notification.Name {
    static let scrollToToday = Notification.Name("scrollToTodayInCalendar")
    static let calendarMonitoringChanged = Notification.Name("calendarMonitoringChanged")
}

struct CalendarMonitoringChange {
    enum Kind: String {
        case movie
        case series
        case episode
    }

    let kind: Kind
    let mediaId: Int
    let instanceId: Instance.ID?
    let monitored: Bool

    init(kind: Kind, mediaId: Int, instanceId: Instance.ID?, monitored: Bool) {
        self.kind = kind
        self.mediaId = mediaId
        self.instanceId = instanceId
        self.monitored = monitored
    }

    init?(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return nil }
        guard let rawKind = userInfo[Key.kind] as? String else { return nil }
        guard let kind = Kind(rawValue: rawKind) else { return nil }
        guard let mediaId = userInfo[Key.mediaId] as? Int else { return nil }
        guard let monitored = userInfo[Key.monitored] as? Bool else { return nil }

        self.kind = kind
        self.mediaId = mediaId
        self.instanceId = userInfo[Key.instanceId] as? Instance.ID
        self.monitored = monitored
    }

    var userInfo: [String: Any] {
        var userInfo: [String: Any] = [
            Key.kind: kind.rawValue,
            Key.mediaId: mediaId,
            Key.monitored: monitored,
        ]

        if let instanceId {
            userInfo[Key.instanceId] = instanceId
        }

        return userInfo
    }

    private enum Key {
        static let kind = "kind"
        static let mediaId = "mediaId"
        static let instanceId = "instanceId"
        static let monitored = "monitored"
    }
}

extension NotificationCenter {
    func post(name: Notification.Name) {
        post(name: name, object: nil)
    }

    func postCalendarMonitoringChange(_ change: CalendarMonitoringChange) {
        post(name: .calendarMonitoringChanged, object: nil, userInfo: change.userInfo)
    }
}
