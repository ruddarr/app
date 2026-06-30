import Foundation
import Observation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class InstancesStore {
    static let shared = InstancesStore()

    #if DEBUG
        nonisolated static let key = "debugInstances"
    #else
        nonisolated static let key = "instances"
    #endif

    @ObservationIgnored private let suite: UserDefaults
    @ObservationIgnored private let cloud: NSUbiquitousKeyValueStore?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private(set) var instances: [Instance] = []

    #if DEBUG
        private static var defaultCloud: NSUbiquitousKeyValueStore? { nil }
    #else
        private static var defaultCloud: NSUbiquitousKeyValueStore? { .default }
    #endif

    init(suite: UserDefaults = .live, cloud: NSUbiquitousKeyValueStore? = InstancesStore.defaultCloud) {
        self.suite = suite
        self.cloud = cloud

        if let cloud {
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
                MainActor.assumeIsolated { self?.cloudChangedExternally(keys: keys) }
            }

            cloud.synchronize()

            #if canImport(UIKit)
                let activation = UIApplication.willEnterForegroundNotification
            #elseif canImport(AppKit)
                let activation = NSApplication.didBecomeActiveNotification
            #endif

            NotificationCenter.default.addObserver(
                cloud,
                selector: #selector(NSUbiquitousKeyValueStore.synchronize),
                name: activation,
                object: nil
            )
        }

        reconcile()
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }

        if let cloud {
            NotificationCenter.default.removeObserver(cloud)
        }
    }

    nonisolated static func decode(_ raw: String?) -> [Instance] {
        raw.flatMap { [Instance](rawValue: $0) } ?? []
    }

    func setInstances(_ new: [Instance]) {
        guard new != instances else { return }
        write(new)
    }

    func reset() {
        let empty = [Instance]().rawValue
        instances = []
        suite.set(empty, forKey: Self.key)
        writeCloud(empty)
    }

    private func write(_ new: [Instance]) {
        instances = new
        let raw = new.rawValue

        suite.set(raw, forKey: Self.key)
        writeCloud(raw)
    }

    private func writeCloud(_ raw: String) {
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
                writeCloud(local.rawValue)
            }
        }
    }

    private func adoptCloudValue() {
        guard let cloud else { return }
        let incoming = Self.decode(cloud.string(forKey: Self.key))

        guard incoming != instances else { return }

        suite.set(incoming.rawValue, forKey: Self.key)
        instances = incoming
    }
}
