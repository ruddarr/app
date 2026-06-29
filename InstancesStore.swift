import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class InstancesStore: ObservableObject {
    static let shared = InstancesStore()

    #if DEBUG
        nonisolated static let key = "debugInstances"
    #else
        nonisolated static let key = "instances"
    #endif

    private let suite: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?

    @Published private(set) var instances: [Instance] = []

    #if DEBUG
        private static var defaultCloud: NSUbiquitousKeyValueStore? { nil }
    #else
        private static var defaultCloud: NSUbiquitousKeyValueStore? { .default }
    #endif

    init(suite: UserDefaults = .live, cloud: NSUbiquitousKeyValueStore? = InstancesStore.defaultCloud) {
        self.suite = suite
        self.cloud = cloud

        if let cloud {
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
                MainActor.assumeIsolated { self?.cloudChangedExternally(keys: keys) }
            }

            cloud.synchronize()

            #if canImport(UIKit)
                NotificationCenter.default.addObserver(
                    cloud,
                    selector: #selector(NSUbiquitousKeyValueStore.synchronize),
                    name: UIApplication.willEnterForegroundNotification,
                    object: nil
                )
            #endif
        }

        reconcile()
    }

    nonisolated static func decode(_ raw: String?) -> [Instance] {
        raw.flatMap { [Instance](rawValue: $0) } ?? []
    }

    func setInstances(_ new: [Instance]) {
        guard new != instances else { return }
        write(new)
    }

    func reset() {
        instances = []
        suite.removeObject(forKey: Self.key)
        cloud?.removeObject(forKey: Self.key)
        cloud?.synchronize()
    }

    private func write(_ new: [Instance]) {
        instances = new
        let raw = new.rawValue

        suite.set(raw, forKey: Self.key)
        cloud?.set(raw, forKey: Self.key)
        cloud?.synchronize()
    }

    private func cloudChangedExternally(keys: [String]?) {
        guard keys == nil || keys?.contains(Self.key) == true else { return }

        adoptCloudValue()
    }

    private func reconcile() {
        if cloud?.object(forKey: Self.key) != nil {
            adoptCloudValue()
        } else {
            let local = Self.decode(suite.string(forKey: Self.key))
            instances = local

            if !local.isEmpty {
                cloud?.set(local.rawValue, forKey: Self.key)
                cloud?.synchronize()
            }
        }
    }

    private func adoptCloudValue() {
        guard let cloud else { return }
        let incoming = Self.decode(cloud.string(forKey: Self.key))
        guard incoming != instances else { return }

        instances = incoming
        suite.set(incoming.rawValue, forKey: Self.key)
    }
}
