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

    func jumpToTab() {
        guard let deeplink else { return }
        try? QuickActions.Deeplink(url: deeplink)()
    }

    var deeplink: URL? {
        switch self {
        case .movie(let movie): movie.calendarDeeplink
        case .episode(let episode): episode.calendarDeeplink
        }
    }
}

struct CalendarSheetContext: Sendable {
    let selection: CalendarSelection
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
    func inCalendarSheet(selection: CalendarSelection, dismiss: @escaping @MainActor () -> Void) -> some View {
        environment(\.inCalendarSheet, CalendarSheetContext(selection: selection, dismiss: dismiss))
    }

    @ViewBuilder
    func calendarSheetToolbar(_ enabled: Bool = true) -> some View {
        if enabled {
            toolbar { CalendarSheetAwareToolbar() }
        } else {
            self
        }
    }
}
