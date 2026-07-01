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

func isPrivateIpAddress(_ ipAddress: String) -> Bool {
    if IPv4Address(ipAddress) != nil {
        return isPrivateIPv4Address(ipAddress)
    }

    if IPv6Address(ipAddress) != nil {
        return isPrivateIPv6Address(ipAddress)
    }

    return false
}

private func isPrivateIPv4Address(_ ipAddress: String) -> Bool {
    let parts = ipAddress.split(separator: ".").map { Int($0) }

    guard parts.count == 4, let first = parts[0], let second = parts[1] else {
        return false
    }

    // 127.0.0.0 - 127.255.255.255 (loopback)
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

    // 169.254.0.0 - 169.254.255.255 (link-local)
    if first == 169 && second == 254 {
        return true
    }

    // 100.64.0.0 - 100.127.255.255 (CGNAT / shared address space)
    if first == 100 && (second >= 64 && second <= 127) {
        return true
    }

    return false
}

private func isPrivateIPv6Address(_ ipAddress: String) -> Bool {
    let normalized = ipAddress.lowercased()

    // ::1 (loopback)
    if normalized == "::1" || normalized == "0000:0000:0000:0000:0000:0000:0000:0001" {
        return true
    }

    // fe80::/10 (link-local)
    if normalized.hasPrefix("fe80:") {
        return true
    }

    // fd00::/8 (unique local address)
    if normalized.hasPrefix("fd") {
        return true
    }

    return false
}
