import Network
import Foundation

actor NetworkMonitor {
    static let shared: NetworkMonitor = NetworkMonitor()

    let monitor = NWPathMonitor()

    static let settleInterval: Duration = .milliseconds(1_500)

    private var status: NWPath.Status = .requiresConnection
    private var pathSignature: String?
    private var pendingSignature: String?
    private var pendingChange: Task<Void, Never>?

    private(set) var pathFacts = NetworkPathFacts()

    var isReachable: Bool {
        status != .unsatisfied
    }

    var localNetworkDenied: Bool {
        LocalNetworkAccess.isDenied
    }

    func start() {
        let updates = AsyncStream<NWPath> { continuation in
            monitor.pathUpdateHandler = { continuation.yield($0) }
        }

        monitor.start(queue: DispatchQueue(label: "Monitor"))

        Task {
            for await path in updates {
                ingest(path)
            }
        }
    }

    func stop() {
        pendingChange?.cancel()
        monitor.cancel()
    }

    private func ingest(_ path: NWPath) {
        status = path.status

        LocalNetworkAccess.setDenied(path.unsatisfiedReason == .localNetworkDenied)

        pathFacts = NetworkPathFacts(
            connection: Self.connectionDescription(of: path),
            constrained: path.isConstrained,
            expensive: path.isExpensive
        )

        let signature = Self.signature(of: path, identity: NetworkSnapshot.capture().identity)

        guard pathSignature != nil else {
            pathSignature = signature
            return
        }

        guard signature != pathSignature else {
            pendingChange?.cancel()
            pendingSignature = nil
            return
        }

        guard signature != pendingSignature else { return }

        pendingChange?.cancel()
        pendingSignature = signature

        pendingChange = Task {
            try? await Task.sleep(for: Self.settleInterval)
            guard !Task.isCancelled else { return }

            commit(signature)
        }
    }

    private func commit(_ signature: String) {
        pathSignature = signature
        pendingSignature = nil

        Task {
            await InstanceResolver.shared.networkChanged()

            await MainActor.run {
                NotificationCenter.default.post(name: .networkChanged)
            }
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
        "\(path.status)|\(identity)"
    }

    func checkReachability() throws {
        guard isReachable else {
            throw API.Error.notConnectedToInternet
        }
    }
}

struct NetworkPathFacts: Equatable, Sendable {
    var connection: String = "unknown"
    var constrained: Bool = false
    var expensive: Bool = false
}
