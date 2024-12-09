import SwiftUI
import Combine
import AppIntents

@Observable
class Router {
    var selectedTab: TabItem = .movies

    var switchToRadarrInstance: String?
    var switchToSonarrInstance: String?

    var moviesPath: NavigationPath = .init()
    var seriesPath: NavigationPath = .init()
    var calendarPath: NavigationPath = .init()
    var settingsPath: NavigationPath = .init()

    func reset() {
        moviesPath = .init()
        seriesPath = .init()
        calendarPath = .init()
    }
}

enum TabItem: String, Identifiable, Hashable, Sendable {
    var id: Self { self }

    case movies
    case series
    case calendar
    case activity
    case settings

    enum Openable: String, CaseIterable {
        case movies
        case series
        case calendar
        case activity
    }

    var label: String {
        switch self {
        case .movies: String(localized: "Movies")
        case .series: String(localized: "Series")
        case .calendar: String(localized: "Calendar")
        case .activity: String(localized: "Activity")
        case .settings: String(localized: "Settings")
        }
    }

    var icon: String {
        switch self {
        case .movies: "movies"
        case .series: "series"
        case .calendar: "calendar"
        case .activity: "waveform.path.ecg"
        case .settings: "gear"
        }
    }
}

extension TabItem.Openable: AppEnum {
    var tab: TabItem {
        switch self {
        case .movies: .movies
        case .series: .series
        case .calendar: .calendar
        case .activity: .activity
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tab")

    static var caseDisplayRepresentations: [TabItem.Openable: DisplayRepresentation] {[
        .movies: DisplayRepresentation(
            title: "Movies",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "film")
        ),
        .series: DisplayRepresentation(
            title: "Series",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "tv")
        ),
        .calendar: DisplayRepresentation(
            title: "Calendar",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "calendar")
        ),
        .activity: DisplayRepresentation(
            title: "Activity",
            subtitle: nil,
            image: DisplayRepresentation.Image(systemName: "waveform.path.ecg")
        ),
    ]}
}
