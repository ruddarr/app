import SwiftUI
import StoreKit

class Subscription {
    static var group: String = "21452440"
    static var name: String = "Ruddarr+"

    static func entitledToService() async -> Bool {
        do {
            let subscriptions = try await Product.SubscriptionInfo.status(for: group)

            // testflight subscriptions expire fast, accept any state
            if isRunningIn(.testflight) {
                return !subscriptions.isEmpty
            }

            return containsEntitledState(subscriptions)
        } catch {
            leaveBreadcrumb(.error, category: "subscription", message: "entitledToService check failed", data: ["error": error])
        }

        return false
    }

    static func containsEntitledState(_ statuses: [StoreKit.Product.SubscriptionInfo.Status]) -> Bool {
        statuses.contains {
            $0.state == .subscribed || $0.state == .inGracePeriod
        }
    }

    static func lastEntitledDate() async -> Date? {
        let key = "lastEntitledAt"

        if await entitledToService() {
            dependencies.store.set(Date(), forKey: key)

            return Date()
        }

        if let lastDate = dependencies.store.object(forKey: key) as? Date {
            return lastDate
        }

        return nil
    }

    static func status(from statuses: [StoreKit.Product.SubscriptionInfo.Status]) -> SubscriptionStatus {
        if statuses.count == 0 {
            return .notSubscribed
        }

        if statuses.count > 1 {
            leaveBreadcrumb(.fatal, category: "subscription", message: "More than one status", data: ["statuses": statuses])
        }

        return switch statuses[0].state {
        case .subscribed: .subscribed
        case .expired: .expired
        case .inBillingRetryPeriod: .inBillingRetryPeriod
        case .inGracePeriod: .inGracePeriod
        case .revoked: .revoked
        default: .unknown
        }
    }
}

enum SubscriptionStatus {
    case subscribed
    case notSubscribed
    case expired
    case inBillingRetryPeriod
    case inGracePeriod
    case revoked
    case error
    case unknown

    var label: LocalizedStringKey {
        switch self {
        case .subscribed: "Active"
        case .notSubscribed: "Not Subscribed"
        case .expired: "Expired"
        case .inBillingRetryPeriod: "Inactive"
        case .inGracePeriod: "Active"
        case .revoked: "Revoked"
        case .error: "Error"
        case .unknown: "Unknown"
        }
    }
}

struct RuddarrPlusSheet: View {
    let privacy = URL(string: "https://ruddarr.com/privacy")!
    let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        SubscriptionStoreView(groupID: Subscription.group, visibleRelationships: .all) {
             RuddarrPlusSheetContent()
        }
        .subscriptionStoreButtonLabel(.action)
        // .storeButton(.visible, for: .redeemCode)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: privacy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: terms, for: .termsOfService)
        .tint(.blue)
    }
}

struct RuddarrPlusSheetContent: View {
    var body: some View {
        VStack {
            Image(appIcon: "AppIcon")
                .resizable()
                .frame(width: 75, height: 75)
                .clipShape(.rect(cornerRadius: (10 / 57) * 75))
                .padding(.bottom, 8)

            Text(verbatim: Subscription.name)
                .font(.largeTitle.bold())
                .padding(.bottom, 4)

            Text("Subscription unlocks instance notifications, alternate app icons and supports the continued indie development of Ruddarr.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
