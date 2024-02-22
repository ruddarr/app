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
    
    func goToSearch(initialQuery: String = "") {
        selectedTab = .movies
        // if they were already navigated somewhere within movies tab, they lose that.
        dependencies.router.moviesPath = .init([MoviesView.Path.search(initialQuery)])
    }
}

enum Tab: Hashable, CaseIterable, Identifiable {
    var id: Self { self }

    case movies
    case shows
    case settings

    @ViewBuilder
    var label: some View {
        switch self {
        case .movies:
            Label("Movies", systemImage: "film")
        case .shows:
            Label("Series", systemImage: "tv")
        case .settings:
            Label("Settings", systemImage: "gear")
        }
    }

    @ViewBuilder
    var row: some View {
        let text = switch self {
        case .movies: "Movies"
        case .shows: "Series"
        case .settings: "Settings"
        }

        let icon = switch self {
        case .movies: "film"
        case .shows: "tv"
        case .settings: "gear"
        }

        Label {
            Text(text)
                .tint(.primary)
                .font(.headline)
                .fontWeight(.regular)
        } icon: {
            Image(systemName: icon).imageScale(.large)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    var stack: some View {
        VStack(spacing: 0) {
            Spacer()
            switch self {
            case .movies:
                Image(systemName: "film").font(.system(size: 23))
                    .frame(height: 15)

                Text("Movies").font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .shows:
                Image(systemName: "tv").font(.system(size: 23))
                    .frame(height: 15)

                Text("Series").font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)
            case .settings:
                Image(systemName: "gear").font(.system(size: 23))
                    .frame(height: 15)

                Text("Settings").font(.system(size: 10, weight: .semibold))
                    .frame(height: 15).padding(.top, 8)

            }
        }
        .frame(height: 50)
    }
}
