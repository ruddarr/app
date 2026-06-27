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
}

private struct CalendarSheetContextKey: EnvironmentKey {
    static let defaultValue: CalendarSheetContext? = nil
}

extension EnvironmentValues {
    var inCalendarSheet: CalendarSheetContext? {
        get { self[CalendarSheetContextKey.self] }
        set { self[CalendarSheetContextKey.self] = newValue }
    }
}

extension View {
    func inCalendarSheet(dismiss: @escaping @MainActor () -> Void) -> some View {
        environment(\.inCalendarSheet, CalendarSheetContext(dismiss: dismiss))
    }
}
