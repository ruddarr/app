import SwiftUI

/// App-wide "the app returned to the foreground" event.
///
/// The app's foreground state is observed in exactly one place per platform — the
/// `Ruddarr` App struct on iOS, where `scenePhase` aggregates all scenes, and
/// `AppDelegateMac` on macOS, using app-level activation — which arms
/// `resignedActive()` when the app leaves the foreground and fires `becameActive()`
/// when it comes back. Views react to it with `.onBecomeActive()`.
///
/// This is deliberately an event and not a state: a view installed after the app resumed
/// never sees it. Loading a view's initial data belongs in `.task`, which already runs on
/// installation, so nothing fetches twice at launch or when pushing a detail view.
@MainActor
@Observable
class Lifecycle {
    static let shared = Lifecycle()

    /// Incremented once per return to the foreground.
    private(set) var resumeCount: Int = 0

    private var leftForeground: Bool = false

    /// Arms the next `becameActive()`, called when the app leaves the foreground.
    func resignedActive() {
        leftForeground = true
    }

    /// Fires the resume event, but only after a real trip out of the foreground.
    /// A cold launch never left the foreground, so it stays silent.
    func becameActive() {
        guard leftForeground else { return }

        leftForeground = false
        resumeCount += 1
    }
}
