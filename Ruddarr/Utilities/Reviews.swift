import SwiftUI
import StoreKit

func maybeAskForReview() {
    let chance: Int = 20
    let days: Double = 14
    let delay: DispatchTime = .now() + 2

    if environment() == .testflight {
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

private func askForReview() {
    #if os(macOS)
        SKStoreReviewController.requestReview()
    #else
        guard let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene else { return }

        SKStoreReviewController.requestReview(in: scene)
    #endif
}
