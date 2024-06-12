import SwiftUI
import Combine

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

    var text: LocalizedStringKey {
        switch self {
        case .movies: "Movies"
        case .series: "Series"
        case .calendar: "Calendar"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .movies: "film"
        case .series: "tv"
        case .calendar: "calendar"
        case .activity: "waveform.path.ecg"
        case .settings: "gear"
        }
    }

    @ViewBuilder
    var label: some View {
        Label(text, systemImage: icon)
    }

    @ViewBuilder
    var row: some View {
        Label {
            Text(text)
                .tint(.primary)
                .font(.headline)
                .fontWeight(.regular)
        } icon: {
            Image(systemName: icon)
                .imageScale(.large)
        }
    }

    @ViewBuilder
    var stack: some View {
        VStack(spacing: 0) {
            Spacer()
            switch self {
            case .movies:
                Image(systemName: icon).font(.system(size: 23))
                    .frame(height: 15)

                Text(text).font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .series:
                Image(systemName: icon).font(.system(size: 23))
                    .frame(height: 15)

                Text(text).font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .calendar:
                Image(systemName: icon).font(.system(size: 23))
                    .frame(height: 15)

                Text(text).font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .activity:
                Image(systemName: icon).font(.system(size: 23))
                    .frame(height: 15)

                Text(text).font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .settings:
                Image(systemName: icon).font(.system(size: 23))
                    .frame(height: 15)

                Text(text).font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)

            }
        }
        .frame(height: 50)
    }
}
