import Network
import Foundation

/// Whether a host is a private / non-routable address — RFC1918, link-local, loopback,
/// CGNAT, or a Tailscale ULA. Delegates to the `NetworkInterfaces` address primitives so
/// the CIDR ranges live in exactly one place (the ones covered by the test suite).
func isPrivateIpAddress(_ ipAddress: String) -> Bool {
    if let v4 = NetworkInterfaces.parseIPv4(ipAddress) {
        return NetworkInterfaces.isPrivateV4(v4) || NetworkInterfaces.isCarrierGradeNAT(v4)
    }

    if let v6 = IPv6Address(ipAddress)?.rawValue, v6.count == 16 {
        let bytes = [UInt8](v6)
        return NetworkInterfaces.isPrivateV6(bytes: bytes) || NetworkInterfaces.isTailscaleULA(bytes: bytes)
    }

    return false
}

/// An IPv4 subnet in host byte order, used for on-link membership tests.
struct IPv4Subnet: Equatable, Hashable {
    let address: UInt32
    let mask: UInt32

    func contains(_ ip: UInt32) -> Bool {
        (ip & mask) == (address & mask)
    }

    /// `network/prefix` for display, e.g. `192.168.1.0/24`.
    var cidr: String {
        let net = address & mask
        let octets = [(net >> 24) & 0xFF, (net >> 16) & 0xFF, (net >> 8) & 0xFF, net & 0xFF]
        return octets.map(String.init).joined(separator: ".") + "/\(mask.nonzeroBitCount)"
    }
}

// An IPv6 subnet, stored as 16 network-order bytes plus a prefix length. IPv6 does not
// NAT, so a server that shares the device's prefix is reachable directly — the same
// "are we on the same link?" question as IPv4.
struct IPv6Subnet: Equatable, Hashable {
    let address: [UInt8]
    let prefix: Int

    func contains(_ other: [UInt8]) -> Bool {
        guard address.count == 16, other.count == 16, (0...128).contains(prefix) else { return false }

        let fullBytes = prefix / 8
        for index in 0..<fullBytes where address[index] != other[index] { return false }

        let remainingBits = prefix % 8
        if remainingBits > 0 {
            let mask = UInt8(truncatingIfNeeded: 0xFF << (8 - remainingBits))
            if (address[fullBytes] & mask) != (other[fullBytes] & mask) { return false }
        }

        return true
    }

    // The address masked to its prefix — the network identity, stable across IPv6
    // privacy/temporary address rotation (which changes host bits, not the prefix).
    var network: [UInt8] {
        guard address.count == 16 else { return address }

        var result = [UInt8](repeating: 0, count: 16)
        let fullBytes = min(prefix, 128) / 8
        for index in 0..<fullBytes { result[index] = address[index] }

        let remainingBits = min(prefix, 128) % 8
        if remainingBits > 0, fullBytes < 16 {
            result[fullBytes] = address[fullBytes] & UInt8(truncatingIfNeeded: 0xFF << (8 - remainingBits))
        }

        return result
    }

    /// `network/prefix` for display, hextets uncompressed (no `::` collapsing).
    var cidr: String {
        let net = network
        guard net.count == 16 else { return "?/\(prefix)" }

        var groups: [String] = []
        var index = 0
        while index < 16 {
            groups.append(String((UInt16(net[index]) << 8) | UInt16(net[index + 1]), radix: 16))
            index += 2
        }

        return groups.joined(separator: ":") + "/\(prefix)"
    }
}
