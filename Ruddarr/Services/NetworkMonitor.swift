import Network
import Foundation

actor NetworkMonitor {
    static let shared: NetworkMonitor = NetworkMonitor()

    let monitor = NWPathMonitor()

    private var status: NWPath.Status = .requiresConnection
    private var unsatisfiedReason: NWPath.UnsatisfiedReason?
    private var pathSignature: String?

    var isReachable: Bool {
        status == .satisfied
    }

    var localNetworkDenied: Bool {
        unsatisfiedReason == .localNetworkDenied
    }

    func start() {
        monitor.pathUpdateHandler = { path in
            Task {
                await self.update(from: path)
            }
        }

        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private func update(from path: NWPath) {
        self.status = path.status
        self.unsatisfiedReason = path.unsatisfiedReason

        let signature = Self.signature(of: path)

        if signature != pathSignature {
            if pathSignature != nil {
                InstanceResolver.shared.networkChanged()
            }

            pathSignature = signature
        }
    }

    private static func signature(of path: NWPath) -> String {
        let interfaces = path.availableInterfaces
            .map { "\($0.name):\($0.type)" }
            .sorted()
            .joined(separator: ",")

        return "\(path.status)|\(interfaces)"
    }

    func checkReachability() throws {
        guard isReachable else {
            throw API.Error.notConnectedToInternet
        }
    }
}
