import SwiftUI

/// App-wide "returned to the foreground" event, delivered to views via `.onBecomeActive()`.
///
/// `resumeCount` increments once per real trip out of the foreground: leaving arms the
/// flag, returning fires it. A cold launch or a view installation can therefore never
/// fire it — initial loads belong in `.task`, resume refreshes in `.onBecomeActive()`.
/// Transient `.inactive` dips (notification banner, control center) deliberately do not
/// refresh.
///
/// Exactly one observer per platform drives it: the `Ruddarr` App struct on iOS, where
/// the App-level `scenePhase` aggregates all scenes (a lone iPadOS window closing or
/// backgrounding never arms it), and `AppDelegateMac` on macOS via app activation,
/// which arms at launch when the app starts inactive so background launches refresh on
/// first foregrounding.
///
/// The action runs on every installed `.onBecomeActive()` instance, visible or not.
/// Do not add an `initial:` option (it would fire per view installation — the original
/// double-fetch bug), and do not switch to `willEnterForegroundNotification` (it fires
/// at cold launch in scene-based apps).
@MainActor
@Observable
class Lifecycle {
    static let shared = Lifecycle()

    private(set) var resumeCount: Int = 0

    private var leftForeground: Bool = false

    func phaseChanged(_: ScenePhase, _ phase: ScenePhase) {
        switch phase {
        case .background: resignedActive()
        case .active: becameActive()
        default: break
        }
    }

    func resignedActive() {
        leftForeground = true
    }

    func becameActive() {
        guard leftForeground else { return }

        leftForeground = false
        resumeCount += 1
    }
}
