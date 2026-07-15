import Foundation
import Observation
import CryptoKit
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
    @ObservationIgnored private var foregroundObserver: (any NSObjectProtocol)?

    private(set) var instances: [Instance] = []

    #if DEBUG
        private static var defaultCloud: NSUbiquitousKeyValueStore? { nil }
    #else
        private static var defaultCloud: NSUbiquitousKeyValueStore? { .default }
    #endif

    init(suite: UserDefaults = .live, cloud: NSUbiquitousKeyValueStore? = InstancesStore.defaultCloud) {
        self.suite = suite
        self.cloud = cloud

        if cloud != nil {
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

            Self.synchronizeCloud()

            #if canImport(UIKit)
                let activation = UIApplication.willEnterForegroundNotification
            #elseif canImport(AppKit)
                let activation = NSApplication.didBecomeActiveNotification
            #endif

            foregroundObserver = NotificationCenter.default.addObserver(
                forName: activation,
                object: nil,
                queue: nil
            ) { _ in
                Self.synchronizeCloud()
            }
        }

        reconcile()
    }

    func start() {
        //
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }

        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    private nonisolated static func synchronizeCloud() {
        Task.detached(priority: .utility) {
            if !NSUbiquitousKeyValueStore.default.synchronize() {
                leaveBreadcrumb(.warning, category: "instances", message: "iCloud synchronize() returned false")
            }
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
        write([], forceCloud: true)
    }

    private func write(_ new: [Instance], forceCloud: Bool = false) {
        let syncWorthy = forceCloud || !new.sameConfiguration(as: instances)

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

        Self.synchronizeCloud()
    }

    private func cloudChangedExternally(reason: Int?, keys: [String]?) {
        if reason == NSUbiquitousKeyValueStoreAccountChange {
            leaveBreadcrumb(.warning, category: "instances", message: "iCloud account changed")
            return adoptCloudValue()
        }

        guard keys == nil || keys?.contains(Self.key) == true else { return }

        adoptCloudValue()
    }

    private func reconcile() {
        let raw = suite.string(forKey: Self.key)
        let decoded = Self.decode(raw)

        if let raw, decoded == nil {
            var data = Self.decodeFailure(raw)
            data["key"] = Self.key

            leaveBreadcrumb(.error, category: "instances", message: "Local instances value could not be decoded", data: data)
        }

        instances = decoded ?? []

        guard cloud != nil else { return }

        adoptCloudValue()
    }

    private func adoptCloudValue() {
        guard let cloud else { return }

        guard let raw = cloud.string(forKey: Self.key) else {
            if let object = cloud.object(forKey: Self.key) {
                leaveBreadcrumb(.error, category: "instances", message: "Ignored non-string iCloud value", data: [
                    "key": Self.key,
                    "class": String(describing: type(of: object)),
                    "local": instances.count,
                ])

                healCloudValue()
            } else if !instances.isEmpty {
                writeCloud(instances.rawValue)
            }

            return
        }

        guard let incoming = Self.decode(raw) else {
            var data = Self.decodeFailure(raw)
            data["key"] = Self.key
            data["local"] = instances.count

            leaveBreadcrumb(.error, category: "instances", message: "Ignored undecodable iCloud value", data: data)

            healCloudValue()

            return
        }

        guard !incoming.sameConfiguration(as: instances) else { return }

        suite.set(raw, forKey: Self.key)
        instances = incoming
    }

    private func healCloudValue() {
        guard !instances.isEmpty else { return }

        writeCloud(instances.rawValue)
    }

    private nonisolated static func decodeFailure(_ raw: String) -> [String: Any] {
        let bytes = Data(raw.utf8)

        var data: [String: Any] = [
            "bytes": bytes.count,
            "digest": String(SHA256.hash(data: bytes).hexEncoded().prefix(8)),
        ]

        do {
            _ = try JSONDecoder().decode([Instance].self, from: bytes)
            data["kind"] = "decoded"
        } catch let error as DecodingError {
            data["kind"] = describe(error)
            data["path"] = error.context.codingPath.map(\.stringValue).joined(separator: ".")
        } catch {
            data["kind"] = "unknown"
        }

        return data
    }

    // A value-free classification of the failure: the case plus the schema key or expected type
    // it concerns — never the rejected value. `Context.debugDescription` is deliberately not read:
    // a `RawRepresentable` enum bakes its invalid raw value into it ("...invalid String value
    // <secret>"), which would leak stored payload contents into the breadcrumb.
    private nonisolated static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): "keyNotFound(\(key.stringValue))"
        case .typeMismatch(let type, _): "typeMismatch(\(type))"
        case .valueNotFound(let type, _): "valueNotFound(\(type))"
        case .dataCorrupted: "dataCorrupted"
        @unknown default: "unknown"
        }
    }
}
