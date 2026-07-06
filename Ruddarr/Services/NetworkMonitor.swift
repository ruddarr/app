import os
import Network
import Foundation

actor NetworkMonitor {
    static let shared: NetworkMonitor = NetworkMonitor()

    let monitor = NWPathMonitor()

    private var status: NWPath.Status = .requiresConnection
    private var pathSignature: String?

    private let pathSequence = OSAllocatedUnfairLock(initialState: 0)
    private var lastSequence = 0

    var isReachable: Bool {
        status == .satisfied
    }

    var localNetworkDenied: Bool {
        LocalNetworkAccess.isDenied
    }

    func start() {
        monitor.pathUpdateHandler = { path in
            let sequence = self.pathSequence.withLock { $0 += 1; return $0 }
            Task {
                await self.update(from: path, sequence: sequence)
            }
        }

        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private func update(from path: NWPath, sequence: Int) {
        guard sequence > lastSequence else { return }
        lastSequence = sequence

        self.status = path.status

        LocalNetworkAccess.setDenied(path.unsatisfiedReason == .localNetworkDenied)

        NetworkPathFacts.update(NetworkPathFacts.Facts(
            connection: Self.connectionDescription(of: path),
            constrained: path.isConstrained,
            expensive: path.isExpensive
        ))

        let signature = Self.signature(of: path, identity: NetworkSnapshot.capture().identity)

        if signature != pathSignature {
            if pathSignature != nil {
                InstanceResolver.shared.networkChanged()

                Task { @MainActor in
                    NotificationCenter.default.post(name: .networkChanged)
                }
            }

            pathSignature = signature
        }
    }

    private static func connectionDescription(of path: NWPath) -> String {
        guard path.status == .satisfied else {
            return "offline"
        }

        let types: [(NWInterface.InterfaceType, String)] = [
            (.wiredEthernet, "ethernet"),
            (.wifi, "wifi"),
            (.cellular, "cellular"),
            (.loopback, "loopback"),
        ]

        var used = types.filter { path.usesInterfaceType($0.0) }.map(\.1)

        // A VPN/tunnel surfaces as the catch-all `.other` interface type. Name the actual
        // interface(s) (`utun3`) instead of the opaque "other" it maps to by default.
        if path.usesInterfaceType(.other) {
            used.append(otherInterfaceDescription(of: path))
        }

        return used.isEmpty ? "unknown" : used.joined(separator: ", ")
    }

    private static func otherInterfaceDescription(of path: NWPath) -> String {
        let names = path.availableInterfaces
            .filter { $0.type == .other }
            .map(\.name)

        return names.isEmpty ? "other" : names.sorted().joined(separator: ", ")
    }

    private static func signature(of path: NWPath, identity: String) -> String {
        let interfaces = path.availableInterfaces
            .map { "\($0.name):\($0.type)" }
            .sorted()
            .joined(separator: ",")

        return "\(path.status)|\(interfaces)|\(identity)"
    }

    func checkReachability() throws {
        guard isReachable else {
            throw API.Error.notConnectedToInternet
        }
    }
}

enum NetworkPathFacts {
    struct Facts: Equatable, Sendable {
        var connection: String = "unknown"
        var constrained: Bool = false
        var expensive: Bool = false
    }

    private static let state = OSAllocatedUnfairLock(initialState: Facts())

    static var current: Facts { state.withLock { $0 } }

    static func update(_ facts: Facts) { state.withLock { $0 = facts } }
}
