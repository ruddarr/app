import Foundation

extension CalendarView {
    func areMoviesInCalendarOrder(_ lhs: Movie, _ rhs: Movie) -> Bool {
        if lhs.monitored != rhs.monitored {
            return lhs.monitored
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    func areEpisodesInCalendarOrder(_ lhs: Episode, _ rhs: Episode) -> Bool {
        let lhsDate = lhs.airDateUtc ?? .distantPast
        let rhsDate = rhs.airDateUtc ?? .distantPast

        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        if lhs.isMonitoredInCalendar != rhs.isMonitoredInCalendar {
            return lhs.isMonitoredInCalendar
        }

        return lhs.episodeNumber < rhs.episodeNumber
    }

    func areBooksInCalendarOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        if lhs.monitored != rhs.monitored {
            return lhs.monitored
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}
