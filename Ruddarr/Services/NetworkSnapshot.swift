import os
import Network
import Foundation

// Proactively picks the right instance URL by reading the device's own network
// interfaces (`getifaddrs`), instead of discovering reachability by waiting for a
// request to time out. This is synchronous, costs one syscall, needs no entitlement
// and triggers no privacy prompt (per Apple TN3179, reading interfaces is never the
// trigger for the Local Network prompt).
//
// Two facts drive the choice, both read straight from the interface table:
//   1. Is the tailnet up?  → a `utun*` interface holding an `fd7a:115c:a1e0::/48` IPv6
//      ULA. The 100.64.0.0/10 (CGNAT) IPv4 Tailscale also assigns is deliberately NOT a
//      tailnet signal: other utun-based VPNs (NetBird, Cloudflare WARP, Pangolin, …) reuse
//      that exact CGNAT block, and carrier-grade NAT hands `pdp*` a 100.64/10 too, so an
//      IPv4 check false-positives. Only the fd7a ULA is Tailscale-specific, so it alone
//      flips `tailnetUp`.
//   2. Is a server's LAN on-link?  → does any real broadcast interface (`en*`) sit in
//      the same subnet as the server, i.e. `(deviceIP & mask) == (serverIP & mask)`.
//
// Everything here is self-contained (no app-only dependencies) so it also compiles
// into the test target, which does not use `@testable import`.

/// How a candidate URL's host relates to the device's networks. Derived purely from the
/// host string via the shared `NetworkInterfaces` address primitives — the same ones
/// `isPrivateIpAddress` now delegates to, so the CIDR classification lives in one place.
enum InstanceURLRole: Equatable {
    case lan        // RFC1918 / link-local / ULA / *.local — reachable only on the server's own link
    case tailscale  // 100.64/10 literal, fd7a:115c:a1e0::/48, or *.ts.net MagicDNS name
    case remote     // public IP, DDNS / reverse-proxy hostname, anything else
}

/// A host's relationship to the device's networks *after* DNS resolution: its role plus,
/// for a LAN address, whether it is actually on-link here. This is what lets a plain
/// hostname — e.g. a split-horizon `radarr.examplehomelab.com` whose A record is a
/// private IP — be ranked by where it really points rather than by how it is spelled.
struct ResolvedHost: Equatable {
    var role: InstanceURLRole
    var onLink: Bool
}

/// An instant, permission-free read of the network facts that decide URL selection.
struct NetworkSnapshot: Equatable {
    var tailnetUp: Bool = false
    var lanV4: [IPv4Subnet] = []
    var lanV6: [IPv6Subnet] = []

    /// Whether the OS has denied this app Local Network access. Mirrored synchronously from
    /// `NetworkMonitor` via `LocalNetworkAccess`, so selection can avoid a LAN candidate that
    /// would only time out. Deliberately not part of `fingerprint`: a denial toggle re-scores
    /// on the next selection, it does not need to invalidate demotions/resolutions.
    var localNetworkDenied: Bool = false

    /// A stable token for the current network. Demotions (URLs that just failed) and
    /// resolved hostnames are scoped to this, so anything learned on one network is
    /// dropped the moment the network changes (the fingerprint changes with it). IPv6
    /// uses the masked prefix, not the live address, so privacy-address rotation on an
    /// otherwise unchanged network does not churn the fingerprint.
    var fingerprint: String {
        let v4 = Set(lanV4.map { "\($0.address & $0.mask)/\($0.mask)" })
            .sorted()
            .joined(separator: ",")

        let v6 = Set(lanV6.map { "\($0.network.map(String.init).joined(separator: "."))/\($0.prefix)" })
            .sorted()
            .joined(separator: ",")

        return "ts:\(tailnetUp)|lan4:\(v4)|lan6:\(v6)"
    }

    /// A finer-grained network identity than `fingerprint`, used by `NetworkMonitor` to decide
    /// whether the network *changed* and cached routing state must be dropped. Where
    /// `fingerprint` masks IPv4 to the subnet — so a URL demoted on one LAN stays demoted across
    /// that whole LAN — this keeps the device's full IPv4 host address.
    var identity: String {
        let v4 = Set(lanV4.map(\.address))
            .sorted()
            .map(String.init)
            .joined(separator: ",")

        let v6 = Set(lanV6.map { $0.network.map(String.init).joined(separator: ".") })
            .sorted()
            .joined(separator: ",")

        return "ts:\(tailnetUp)|v4:\(v4)|v6:\(v6)"
    }

    func isOnLink(_ ip: UInt32) -> Bool {
        lanV4.contains { $0.contains(ip) }
    }

    func isOnLink(_ ip: [UInt8]) -> Bool {
        lanV6.contains { $0.contains(ip) }
    }

    /// Whether any real LAN interface (`en*`) is up — i.e. the device is on some local
    /// network, so a link-only `.local` name has a link it could be reachable on.
    var hasLAN: Bool {
        !lanV4.isEmpty || !lanV6.isEmpty
    }
}

/// A process-wide, synchronously-readable mirror of `NWPathMonitor`'s `.localNetworkDenied`
/// reason: `NetworkMonitor` writes it on every path update, `NetworkSnapshot.capture()` reads
/// it. The bridge exists because selection is synchronous while `NetworkMonitor` is an actor.
enum LocalNetworkAccess {
    private static let deniedFlag = OSAllocatedUnfairLock(initialState: false)

    static var isDenied: Bool { deniedFlag.withLock { $0 } }

    static func setDenied(_ value: Bool) { deniedFlag.withLock { $0 = value } }
}

extension NetworkSnapshot {
    /// Reads the live interface table. Cheap enough (microseconds) to call fresh on
    /// every selection, which sidesteps any stale-cache race — important because a
    /// split-tunnel VPN like Tailscale toggling on/off does not reliably fire an
    /// `NWPathMonitor` update.
    static func capture() -> NetworkSnapshot {
        var snapshot = NetworkSnapshot()
        snapshot.localNetworkDenied = LocalNetworkAccess.isDenied

        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return snapshot }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            ingest(pointer.pointee, into: &snapshot)
        }

        return snapshot
    }

    /// Folds one interface's address into the snapshot, dispatching by address family.
    /// Interfaces that are down or carry no address contribute nothing.
    private static func ingest(_ interface: ifaddrs, into snapshot: inout NetworkSnapshot) {
        let flags = Int32(bitPattern: interface.ifa_flags) // ifa_flags is UInt32

        guard flags & IFF_UP == IFF_UP, flags & IFF_RUNNING == IFF_RUNNING else { return }
        guard let addressPointer = interface.ifa_addr else { return }

        let name = String(cString: interface.ifa_name)
        let family = addressPointer.pointee.sa_family

        if family == sa_family_t(AF_INET) {
            ingestIPv4(name: name, flags: flags, address: addressPointer, netmask: interface.ifa_netmask, into: &snapshot)
        } else if family == sa_family_t(AF_INET6) {
            ingestIPv6(name: name, flags: flags, address: addressPointer, netmask: interface.ifa_netmask, into: &snapshot)
        }
    }

    /// A real `en*` link records its on-link IPv4 subnet. A `utun`'s CGNAT address does
    /// NOT flip `tailnetUp` — that would false-positive every other utun VPN reusing
    /// 100.64/10 (NetBird, WARP, …); tailnet detection is IPv6-fd7a-only (see `ingestIPv6`).
    /// Anything else (bridge, AirDrop, tethering, …) is ignored.
    private static func ingestIPv4(
        name: String,
        flags: Int32,
        address: UnsafeMutablePointer<sockaddr>,
        netmask: UnsafeMutablePointer<sockaddr>?,
        into snapshot: inout NetworkSnapshot
    ) {
        let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
        let mask = netmask?.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        } ?? 0xFFFF_FFFF

        switch classifyV4(name: name, flags: flags, address: value, mask: mask) {
        case .lan(let subnet): snapshot.lanV4.append(subnet)
        case .ignored: break
        }
    }

    /// What one decoded IPv4 interface contributes. Only a real `en*` link contributes (its
    /// subnet); everything else — including a `utun` carrying a 100.64/10 CGNAT address — is
    /// ignored. IPv4 is deliberately NOT a tailnet signal: Tailscale's CGNAT range is shared
    /// by NetBird/WARP/Pangolin and by carrier-grade NAT on `pdp*`, so the tailnet is
    /// identified only by its `fd7a:115c:a1e0::/48` IPv6 ULA (see `classifyV6`).
    /// Pure and testable — the `getifaddrs` pointer decoding stays in `ingestIPv4`.
    enum V4Contribution: Equatable {
        case lan(IPv4Subnet)
        case ignored
    }

    static func classifyV4(name: String, flags: Int32, address: UInt32, mask: UInt32) -> V4Contribution {
        if isLANEthernet(name: name, flags: flags) { return .lan(IPv4Subnet(address: address, mask: mask)) }
        return .ignored
    }

    /// A Tailscale `utun` (its `fd7a:115c:a1e0::/48` ULA) flips `tailnetUp`; a real `en*`
    /// link records its routable IPv6 prefix. Link-local (`fe80::/10`) is skipped — every
    /// interface has one and it can't address a server without a zone id.
    private static func ingestIPv6(
        name: String,
        flags: Int32,
        address: UnsafeMutablePointer<sockaddr>,
        netmask: UnsafeMutablePointer<sockaddr>?,
        into snapshot: inout NetworkSnapshot
    ) {
        let bytes = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
            NetworkInterfaces.ipv6Bytes($0.pointee.sin6_addr)
        }
        let prefix = netmask?.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
            NetworkInterfaces.prefixLength(of: $0.pointee.sin6_addr)
        } ?? 128

        switch classifyV6(name: name, flags: flags, address: bytes, prefix: prefix) {
        case .tailnet: snapshot.tailnetUp = true
        case .lan(let subnet): snapshot.lanV6.append(subnet)
        case .ignored: break
        }
    }

    /// What one decoded IPv6 interface contributes. A `utun` carrying the `fd7a:115c:a1e0::/48`
    /// ULA is the tailnet; a real `en*` link records its routable prefix (link-local skipped —
    /// unaddressable without a zone id); anything else is ignored. Pure and testable.
    enum V6Contribution: Equatable {
        case tailnet
        case lan(IPv6Subnet)
        case ignored
    }

    static func classifyV6(name: String, flags: Int32, address: [UInt8], prefix: Int) -> V6Contribution {
        if name.hasPrefix("utun"), NetworkInterfaces.isTailscaleULA(bytes: address) { return .tailnet }
        if isLANEthernet(name: name, flags: flags) {
            if NetworkInterfaces.isLinkLocalV6(bytes: address) { return .ignored }
            return .lan(IPv6Subnet(address: address, prefix: prefix))
        }
        return .ignored
    }

    /// Wi-Fi / wired Ethernet (`en*`) that can host a home LAN — excluding
    /// bridge*/vmnet*/awdl*/llw*/utun*/pdp*, point-to-point and loopback links, so VM,
    /// AirDrop and tethering interfaces never masquerade as a home LAN.
    private static func isLANEthernet(name: String, flags: Int32) -> Bool {
        name.hasPrefix("en") && flags & IFF_POINTOPOINT == 0 && flags & IFF_LOOPBACK == 0
    }
}
