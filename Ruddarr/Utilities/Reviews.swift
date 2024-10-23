import SwiftUI
import StoreKit

func maybeAskForReview() {
    let chance: Int = 20
    let days: Double = 14
    let delay: DispatchTime = .now() + 5

    let sevenDaysAgo: Double = -7 * 24 * 60 * 60

    if let installedOn = inferredInstallDate(), installedOn.timeIntervalSinceNow > sevenDaysAgo {
        return
    }

    if isRunningIn(.testflight) {
        return
    }

    if Occurrence.daysSince("reviewRequest") < days {
        return
    }

    if chance < Int.random(in: 1..<101) {
        return
    }

    DispatchQueue.main.asyncAfter(deadline: delay) {
        askForReview()
        Occurrence.occurred("reviewRequest")
    }
}

@MainActor
private func askForReview() {
    #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene else { return }

        AppStore.requestReview(in: scene)
    #endif
}
