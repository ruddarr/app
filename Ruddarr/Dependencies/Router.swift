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
    case shows
    case settings

    @ViewBuilder
    var label: some View {
        switch self {
        case .movies:
            Label("Movies", systemImage: "popcorn.fill")
        case .shows:
            Label("Shows", systemImage: "tv.inset.filled")
        case .settings:
            Label("Settings", systemImage: "gear")
        }
    }
}
