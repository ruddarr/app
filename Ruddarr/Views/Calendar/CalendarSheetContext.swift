import SwiftUI

enum CalendarSelection: Identifiable {
    case movie(Movie)
    case episode(Episode)

    var id: String {
        switch self {
        case .movie(let movie):
            "movie:\(movie.instanceId?.uuidString ?? "unknown"):\(movie.id)"
        case .episode(let episode):
            "episode:\(episode.instanceId?.uuidString ?? "unknown"):\(episode.id)"
        }
    }

    @MainActor
    func jumpToTab() {
        guard let deeplink else { return }
        try? QuickActions.Deeplink(url: deeplink)()
    }

    var deeplink: URL? {
        switch self {
        case .movie(let movie): movie.deeplink
        case .episode(let episode): episode.deeplink
        }
    }
}

struct CalendarSheetContext {
    let dismiss: @MainActor () -> Void
    let pop: @MainActor () -> Void
}

extension View {
    func inCalendarSheet(
        dismiss: @escaping @MainActor () -> Void,
        path: Binding<NavigationPath>
    ) -> some View {
        environment(\.inCalendarSheet, CalendarSheetContext(
            dismiss: dismiss,
            pop: {
                if !path.wrappedValue.isEmpty {
                    path.wrappedValue.removeLast()
                }
            }
        ))
    }
}
