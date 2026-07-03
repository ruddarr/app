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

        let signature = Self.signature(of: path, identity: NetworkSnapshot.capture().identity)

        if signature != pathSignature {
            if pathSignature != nil {
                InstanceResolver.shared.networkChanged()
            }

            pathSignature = signature
        }
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
