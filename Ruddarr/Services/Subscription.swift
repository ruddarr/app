import SwiftUI
import StoreKit

class Subscription {
    static var group: String = "21452440"

    static func entitledToService() async -> Bool {
        do {
            let subscriptions = try await Product.SubscriptionInfo.status(for: group)

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
}

struct RuddarrPlusSheet: View {
    var body: some View {
        SubscriptionStoreView(groupID: Subscription.group, visibleRelationships: .all) {
             RuddarrPlusSheetContent()
        }
        .subscriptionStoreButtonLabel(.action)
        // .storeButton(.visible, for: .redeemCode)
        .storeButton(.visible, for: .restorePurchases)
        .tint(.blue)
    }
}

struct RuddarrPlusSheetContent: View {
    var body: some View {
        VStack {
            Image(uiImage: UIImage(named: "AppIcon")!)
                .resizable()
                .frame(width: 75, height: 75)
                .clipShape(.rect(cornerRadius: (10 / 57) * 75))
                .padding(.bottom, 8)

            Text("Ruddarr+")
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
