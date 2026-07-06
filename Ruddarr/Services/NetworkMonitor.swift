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

    /// The interface type(s) the current path actually uses, for the diagnostics screen.
    private static func connectionDescription(of path: NWPath) -> String {
        guard path.status == .satisfied else { return "offline" }

        let types: [(NWInterface.InterfaceType, String)] = [
            (.wiredEthernet, "Ethernet"),
            (.wifi, "Wi-Fi"),
            (.cellular, "Cellular"),
            (.loopback, "Loopback"),
            (.other, "Other"),
        ]

        let used = types.filter { path.usesInterfaceType($0.0) }.map(\.1)

        return used.isEmpty ? "unknown" : used.joined(separator: ", ")
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

/// A process-wide, synchronously-readable mirror of the `NWPath` facts only the monitor sees —
/// interface type, Low Data Mode (constrained) and expensive (cellular/hotspot) flags — for the
/// diagnostics report. Same bridge pattern as `LocalNetworkAccess`: `NetworkMonitor` writes on
/// every path update, readers never touch the actor.
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
