import Foundation

/// The wait budget for an API request, split by the candidate URL's locality: a LAN candidate
/// uses the short `local` budget so a dead/absent local URL fails over fast, while remote and
/// Tailscale candidates keep `remote`. `local < remote` is reserved for reachability-bound calls —
/// `URLRequest.timeoutInterval` is a "max interval with no data" ceiling, so server-processing-bound
/// calls (lookups, searches, large fetches) must be symmetric (`init(_:)`) or a slow-but-alive LAN
/// response would be truncated.
struct RequestTimeout: Sendable, Equatable {
    let local: Double
    let remote: Double

    init(_ both: Double) {
        local = both
        remote = both
    }

    init(local: Double, remote: Double) {
        assert(local <= remote, "local is a reachability budget; server-processing-bound calls must be symmetric")
        self.local = min(local, remote)
        self.remote = remote
    }

    static let `default` = RequestTimeout(local: 2.5, remote: 10)

    func interval(isLocal: Bool) -> Double {
        isLocal ? local : remote
    }
}

/// Whether a host is a private / non-routable address — RFC1918, link-local, loopback,
/// CGNAT, or a Tailscale ULA. Delegates to the `NetworkInterfaces` address primitives so
/// the CIDR ranges live in exactly one place (the ones covered by the test suite).
func isPrivateIpAddress(_ ipAddress: String) -> Bool {
    if let v4 = NetworkInterfaces.parseIPv4(ipAddress) {
        return NetworkInterfaces.isPrivateV4(v4) || NetworkInterfaces.isCarrierGradeNAT(v4)
    }

    if let bytes = NetworkInterfaces.parseIPv6(ipAddress) {
        return NetworkInterfaces.isPrivateV6(bytes: bytes) || NetworkInterfaces.isTailscaleULA(bytes: bytes)
    }

    return false
}

/// An IPv4 subnet in host byte order, used for on-link membership tests.
struct IPv4Subnet: Equatable, Hashable, Sendable {
    let address: UInt32
    let mask: UInt32

    func contains(_ ip: UInt32) -> Bool {
        (ip & mask) == (address & mask)
    }

    /// For diagnostics octet coloring: whether this subnet's network agrees with `octet` at byte
    /// `index` (0 = high byte … 3 = low byte). `nil` when the octet is unknown (a masked `*`) or
    /// lies wholly in the host portion (mask byte 0) — neither confirms nor denies a match, so the
    /// caller leaves it uncolored.
    func networkOctetMatches(_ octet: UInt8?, at index: Int) -> Bool? {
        guard (0..<4).contains(index) else { return nil }

        let shift = 24 - 8 * index
        let maskByte = UInt8((mask >> shift) & 0xFF)
        guard maskByte != 0, let octet else { return nil }

        let networkByte = UInt8(((address & mask) >> shift) & 0xFF)
        return (octet & maskByte) == (networkByte & maskByte)
    }

    /// The number of leading network octets that match `octets` — how the diagnostics screen picks
    /// the closest reference subnet for an address.
    func commonNetworkOctets(with octets: [UInt8?]) -> Int {
        var count = 0
        for index in 0..<min(4, octets.count) {
            guard networkOctetMatches(octets[index], at: index) == true else { break }
            count += 1
        }
        return count
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
struct IPv6Subnet: Equatable, Hashable, Sendable {
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
