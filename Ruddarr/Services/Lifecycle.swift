import SwiftUI

@MainActor
@Observable
class Lifecycle {
    static let shared = Lifecycle()

    private(set) var resumeCount: Int = 0

    private var leftForeground: Bool = false

    func resignedActive() {
        leftForeground = true
    }

    func becameActive() {
        guard leftForeground else { return }

        leftForeground = false
        resumeCount += 1
    }
}
