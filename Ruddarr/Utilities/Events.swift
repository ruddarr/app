import Foundation

extension Notification.Name {
    static let scrollToToday = Notification.Name("scrollToTodayInCalendar")
    static let activateMoviesSearch = Notification.Name("activateMoviesSearch")
    static let activateSeriesSearch = Notification.Name("activateSeriesSearch")
}

extension NotificationCenter {
    func post(name: Notification.Name) {
        post(name: name, object: nil)
    }
}
