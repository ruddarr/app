import Foundation
import SwiftUI

@Observable
final class Router {
    static let shared = Router()

    var selectedTab: Tab = .movies

    var moviesPath: NavigationPath = .init()
    var settingsPath: NavigationPath = .init()

    func reset() {
        moviesPath = .init()
    }
}

enum Tab: Hashable, CaseIterable, Identifiable {
    var id: Self { self }

    case movies
    case series
    case calendar
    case settings

    var text: String {
        switch self {
        case .movies: String(localized: "Movies")
        case .series: String(localized: "Series")
        case .calendar: String(localized: "Calendar")
        case .settings: String(localized: "Settings")
        }
    }

    var icon: String {
        switch self {
        case .movies: "film"
        case .series: "tv"
        case .calendar: "calendar"
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
