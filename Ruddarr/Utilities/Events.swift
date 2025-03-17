import Foundation

extension Notification.Name {
    static let scrollToToday = Notification.Name("scrollToTodayInCalendar")
}

extension NotificationCenter {
    func post(name: Notification.Name) {
        post(name: name, object: nil)
    }
}
