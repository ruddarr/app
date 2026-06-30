import Foundation
import Observation
import Sentry

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
                let info = note.userInfo
                let reason = info?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                let keys = info?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
                MainActor.assumeIsolated { self?.cloudChangedExternally(reason: reason, keys: keys) }
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

    nonisolated static func decode(_ raw: String?) -> [Instance]? {
        guard let raw else { return nil }
        return [Instance](rawValue: raw)
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
        let syncWorthy = !new.sameConfiguration(as: instances)

        instances = new
        let raw = new.rawValue

        suite.set(raw, forKey: Self.key)

        if syncWorthy {
            writeCloud(raw)
        }
    }

    private func writeCloud(_ raw: String) {
        guard let cloud else { return }

        cloud.set(raw, forKey: Self.key)

        if !cloud.synchronize() {
            leaveBreadcrumb(.warning, category: "instances", message: "iCloud synchronize() returned false")
        }
    }

    private func cloudChangedExternally(reason: Int?, keys: [String]?) {
        if reason == NSUbiquitousKeyValueStoreAccountChange {
            leaveBreadcrumb(.warning, category: "instances", message: "Ignored iCloud account change")
            return
        }

        guard keys == nil || keys?.contains(Self.key) == true else { return }

        adoptCloudValue()
    }

    private func reconcile() {
        let raw = suite.string(forKey: Self.key)
        let decoded = Self.decode(raw)

        if raw != nil && decoded == nil {
            leaveBreadcrumb(.error, category: "instances", message: "Local instances value could not be decoded", data: ["key": Self.key])
        }

        instances = decoded ?? []

        guard cloud != nil else { return }

        adoptCloudValue()
    }

    private func adoptCloudValue() {
        guard let cloud else { return }

        guard let incoming = Self.decode(cloud.string(forKey: Self.key)) else {
            if cloud.object(forKey: Self.key) != nil {
                leaveBreadcrumb(.error, category: "instances", message: "Ignored undecodable iCloud value", data: ["key": Self.key])
            }

            if !instances.isEmpty {
                writeCloud(instances.rawValue)
            }

            return
        }

        guard incoming != instances else { return }

        suite.set(incoming.rawValue, forKey: Self.key)
        instances = incoming
    }
}
