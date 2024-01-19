import Foundation
import Network

class NetworkMonitor {
    static let shared: NetworkMonitor = NetworkMonitor()

    let monitor = NWPathMonitor()
    private var status: NWPath.Status = .requiresConnection
    var isReachable: Bool { status == .satisfied }

    func start() {
        monitor.pathUpdateHandler = { path in
            self.status = path.status
        }

        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

extension NetworkMonitor {
    func checkReachability() throws {
        guard isReachable else { throw URLError(.notConnectedToInternet) }
    }
}
