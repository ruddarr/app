import SwiftUI
import Combine
import AppIntents

@Observable
final class Router {
    static let shared = Router()

    var selectedTab: Tab = .movies

    var switchToRadarrInstance: Instance.ID?
    var switchToSonarrInstance: Instance.ID?

    var moviesPath: NavigationPath = .init()
    var seriesPath: NavigationPath = .init()
    var calendarPath: NavigationPath = .init()
    var settingsPath: NavigationPath = .init()

    let moviesScroll = PassthroughSubject<Void, Never>()
    let seriesScroll = PassthroughSubject<Void, Never>()
    let calendarScroll = PassthroughSubject<Void, Never>()

    func reset() {
        moviesPath = .init()
        seriesPath = .init()
        calendarPath = .init()
    }
}

enum Tab: String, Hashable, CaseIterable, Identifiable {
    var id: Self { self }

    case movies
    case series
    case calendar
    case activity
    case settings

    enum Openable: String {
        case movies
        case series
        case calendar
        case activity
    }

    var text: LocalizedStringKey {
        switch self {
        case .movies: "Movies"
        case .series: "Series"
        case .calendar: "Calendar"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    var icon: Image {
        switch self {
        case .movies: Image("movies")
        case .series: Image("series")
        case .calendar: Image(systemName: "calendar")
        case .activity: Image(systemName: "waveform.path.ecg")
        case .settings: Image(systemName: "gear")
        }
    }

    @ViewBuilder
    var label: some View {
        Label { Text(text) } icon: { icon }
    }

    @ViewBuilder
    var row: some View {
        Label {
            Text(text)
                .tint(.primary)
                .font(.headline)
                .fontWeight(.regular)
        } icon: {
            icon.imageScale(.large)
        }
    }
}

extension Tab.Openable: AppEnum {
    var tab: Tab {
        switch self {
        case .movies: .movies
        case .series: .series
        case .calendar: .calendar
        case .activity: .activity
        }
    }

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tab")

    static var caseDisplayRepresentations: [Tab.Openable: DisplayRepresentation] {[
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
