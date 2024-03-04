import StoreKit

class Subscription {
    static var group: String = "21452440"

    static func entitledToService() async -> Bool {
        do {
            let subscriptions = try await Product.SubscriptionInfo.status(for: group)

            return subscriptions.contains {
                $0.state == .subscribed || $0.state == .inGracePeriod
            }
        } catch {
            leaveBreadcrumb(.error, category: "subscription", message: "User record lookup failed", data: ["error": error])
        }

        return false
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
