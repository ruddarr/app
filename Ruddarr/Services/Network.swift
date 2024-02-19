import Network
import Foundation

class NetworkMonitor {
    static let shared: NetworkMonitor = NetworkMonitor()

    let monitor = NWPathMonitor()

    private var status: NWPath.Status = .requiresConnection

    var isReachable: Bool {
        status == .satisfied
    }

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

    func checkReachability() throws {
        guard isReachable else {
            throw URLError(.notConnectedToInternet)
        }
    }
}

func isPrivateIpAddress(_ ipAddress: String) -> Bool {
    guard IPv4Address(ipAddress) != nil else {
        return false
    }

    let parts = ipAddress.split(separator: ".").map { Int($0) }

    guard parts.count == 4, let first = parts[0], let second = parts[1] else {
        return false
    }

    // 127.0.0.0 - 127.255.255.255 (loopback address)
    if first == 127 {
        return true
    }

    // 10.0.0.0 - 10.255.255.255 (private)
    if first == 10 {
        return true
    }

    // 172.16.0.0 - 172.31.255.255 (private)
    if first == 172 && (second >= 16 && second <= 31) {
        return true
    }

    // 192.168.0.0 - 192.168.255.255 (private)
    if first == 192 && second == 168 {
        return true
    }

    return false
}
