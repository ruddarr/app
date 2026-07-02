import Network
import Foundation

enum NetworkInterfaces {
    /// 100.64.0.0/10 — shared address space used by Tailscale (and, on the wrong
    /// interface, carrier-grade NAT, which is why callers also check the interface name).
    static func isCarrierGradeNAT(_ ip: UInt32) -> Bool {
        (ip & 0xFFC0_0000) == 0x6440_0000
    }

    /// RFC1918, link-local and loopback. CGNAT is intentionally excluded here — it is
    /// classified as `.tailscale`, not `.lan`.
    static func isPrivateV4(_ ip: UInt32) -> Bool {
        (ip & 0xFF00_0000) == 0x0A00_0000 ||   // 10.0.0.0/8
        (ip & 0xFFF0_0000) == 0xAC10_0000 ||   // 172.16.0.0/12
        (ip & 0xFFFF_0000) == 0xC0A8_0000 ||   // 192.168.0.0/16
        (ip & 0xFFFF_0000) == 0xA9FE_0000 ||   // 169.254.0.0/16 (link-local)
        (ip & 0xFF00_0000) == 0x7F00_0000      // 127.0.0.0/8 (loopback)
    }

    /// Loopback (`127.0.0.0/8`). Always reachable — it *is* this device — so it must rank as
    /// on-link on every network, ahead of any remote URL (a server on the same Mac).
    static func isLoopbackV4(_ ip: UInt32) -> Bool {
        (ip & 0xFF00_0000) == 0x7F00_0000
    }

    /// `fd7a:115c:a1e0::/48` — Tailscale's IPv6 ULA range.
    static func isTailscaleULA(bytes: [UInt8]) -> Bool {
        bytes.count >= 6
            && bytes[0] == 0xfd && bytes[1] == 0x7a && bytes[2] == 0x11
            && bytes[3] == 0x5c && bytes[4] == 0xa1 && bytes[5] == 0xe0
    }

    /// `fe80::/10` — link-local. Present on every interface and never routable without a
    /// zone id, so on its own it identifies neither a LAN nor a reachable server address.
    static func isLinkLocalV6(bytes: [UInt8]) -> Bool {
        bytes.count == 16 && bytes[0] == 0xfe && (bytes[1] & 0xC0) == 0x80
    }

    /// RFC4193 unique-local (`fc00::/7`), link-local (`fe80::/10`) and loopback (`::1`) —
    /// the IPv6 analogue of `isPrivateV4`. Reachable only on some link, never routable.
    static func isPrivateV6(bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else { return false }

        if (bytes[0] & 0xFE) == 0xFC { return true }                       // fc00::/7
        if isLinkLocalV6(bytes: bytes) { return true }                     // fe80::/10
        if bytes.dropLast().allSatisfy({ $0 == 0 }), bytes[15] == 1 { return true } // ::1

        return false
    }

    /// Loopback (`::1`) — same rationale as `isLoopbackV4`, always reachable locally.
    static func isLoopbackV6(bytes: [UInt8]) -> Bool {
        bytes.count == 16 && bytes.dropLast().allSatisfy { $0 == 0 } && bytes[15] == 1
    }

    /// The 16 network-order bytes of an `in6_addr`.
    static func ipv6Bytes(_ address: in6_addr) -> [UInt8] {
        var value = address
        return withUnsafeBytes(of: &value) { Array($0.prefix(16)) }
    }

    /// The prefix length encoded by an IPv6 netmask — a contiguous run of set bits.
    static func prefixLength(of mask: in6_addr) -> Int {
        ipv6Bytes(mask).reduce(0) { $0 + $1.nonzeroBitCount }
    }

    /// Parses a dotted-quad into a host-order `UInt32`. Returns `nil` for hostnames.
    static func parseIPv4(_ host: String) -> UInt32? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }

        var result: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            result = (result << 8) | octet
        }

        return result
    }

    static func role(forHost host: String) -> InstanceURLRole {
        let host = host.lowercased()

        if host.hasSuffix(".ts.net") { return .tailscale }
        if host.hasSuffix(".local") { return .lan }

        if let v4 = parseIPv4(host) {
            if isCarrierGradeNAT(v4) { return .tailscale }
            return isPrivateV4(v4) ? .lan : .remote
        }

        if let raw = IPv6Address(host)?.rawValue, raw.count == 16 {
            let bytes = [UInt8](raw)
            if isTailscaleULA(bytes: bytes) { return .tailscale } // fd7a:115c:a1e0::/48
            if isPrivateV6(bytes: bytes) { return .lan }          // fc00::/7, fe80::/10, ::1
            return .remote
        }

        return .remote // bare hostname / DDNS / public address
    }

    /// Extracts the host from a base URL string (e.g. `https://10.0.0.5:7878`),
    /// stripping any IPv6 brackets.
    static func host(of base: String) -> String? {
        guard let host = URLComponents(string: base)?.host else { return nil }
        let unbracketed = host.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        return unbracketed.hasSuffix(".") ? String(unbracketed.dropLast()) : unbracketed // FQDN root dot: nas.local. == nas.local
    }

    /// Buckets a host by the addresses it actually resolves to on the current network.
    /// On-link (v4 or v6) beats everything; a private/ULA address that is *not* on-link
    /// is a LAN URL for some other network (so it loses to a routable one); CGNAT or the
    /// `fd7a:115c:a1e0::/48` ULA is the tailnet; anything else is remote. This is what
    /// distinguishes a split-horizon name (private A/AAAA record) from a public one.
    static func classify(ipv4: [UInt32], ipv6: [in6_addr], snapshot: NetworkSnapshot) -> ResolvedHost {
        let v6 = ipv6.map(ipv6Bytes)

        if ipv4.contains(where: isLoopbackV4) || v6.contains(where: { isLoopbackV6(bytes: $0) }) {
            return ResolvedHost(role: .lan, onLink: true) // a name that resolves to loopback (e.g. `localhost`)
        }

        if ipv4.contains(where: { snapshot.isOnLink($0) }) || v6.contains(where: { snapshot.isOnLink($0) }) {
            return ResolvedHost(role: .lan, onLink: true)
        }

        if ipv4.contains(where: isCarrierGradeNAT) || v6.contains(where: { isTailscaleULA(bytes: $0) }) {
            return ResolvedHost(role: .tailscale, onLink: false)
        }

        if ipv4.contains(where: isPrivateV4) || v6.contains(where: { isPrivateV6(bytes: $0) }) {
            return ResolvedHost(role: .lan, onLink: false)
        }

        return ResolvedHost(role: .remote, onLink: false)
    }

    /// Maps a `(role, on-link)` pair to its selection score — the single source of the
    /// ladder: on-link LAN (home) ► Tailscale up ► remote ► off-link/ambiguous private ►
    /// Tailscale down (a `*.ts.net` with the tunnel off would only NXDOMAIN).
    private static func score(role: InstanceURLRole, onLink: Bool, tailnetUp: Bool) -> Int {
        switch role {
        case .lan: return onLink ? 100 : 30
        case .tailscale: return tailnetUp ? 90 : 5
        case .remote: return 50
        }
    }

    /// On-link test for a *literal* IP host (v4 or v6) — used when a candidate is an IP
    /// address rather than a name that needs resolving.
    private static func literalOnLink(_ host: String, snapshot: NetworkSnapshot) -> Bool {
        if let v4 = parseIPv4(host) { return isLoopbackV4(v4) || snapshot.isOnLink(v4) }
        if let v6 = IPv6Address(host)?.rawValue, v6.count == 16 {
            let bytes = [UInt8](v6)
            return isLoopbackV6(bytes: bytes) || snapshot.isOnLink(bytes)
        }
        return false
    }

    /// A `.local` (mDNS/Bonjour) name resolves only over the local link, and is never sent
    /// to `getaddrinfo`, so it can't be classified by address. Treat it as on-link exactly
    /// when the device has an `en*` LAN up: at home that makes it outrank remote/Tailscale
    /// as intended; away (no LAN) it stays off-link and correctly loses, since it couldn't
    /// resolve there anyway. A wrong pick on some other LAN fails fast and demotes.
    private static func dotLocalOnLink(_ host: String, snapshot: NetworkSnapshot) -> Bool {
        host.lowercased().hasSuffix(".local") && snapshot.hasLAN
    }

    /// One candidate's standing on the current network: its role, whether it is on-link,
    /// its selection score, and whether it is currently demoted. Backs both the ordering
    /// and the bug-report breakdown, so the report explains exactly what selection saw.
    struct CandidateRanking: Equatable {
        let base: String
        let role: InstanceURLRole
        let onLink: Bool
        let score: Int
        let demoted: Bool
    }

    /// Scores and sorts candidates, best-first. A host in `resolved` is judged by where it
    /// really points (split-horizon names included); otherwise the lexical role is used,
    /// so a name whose lookup has not landed yet is never ranked worse than before.
    /// `demoted` bases sink to the back; ties keep the caller's order (canonical first).
    static func ranking(
        _ candidates: [String],
        snapshot: NetworkSnapshot,
        demoted: Set<String> = [],
        resolved: [String: ResolvedHost] = [:]
    ) -> [CandidateRanking] {
        func evaluate(_ base: String) -> (role: InstanceURLRole, onLink: Bool, score: Int) {
            guard let host = host(of: base) else { return (.remote, false, 0) }

            let chosenRole: InstanceURLRole
            let onLink: Bool

            if let resolution = resolved[host] {
                chosenRole = resolution.role
                onLink = resolution.onLink
            } else {
                switch role(forHost: host) {
                case .lan: chosenRole = .lan; onLink = literalOnLink(host, snapshot: snapshot) || dotLocalOnLink(host, snapshot: snapshot)
                case .tailscale: chosenRole = .tailscale; onLink = false
                case .remote: chosenRole = .remote; onLink = false
                }
            }

            return (chosenRole, onLink, score(role: chosenRole, onLink: onLink, tailnetUp: snapshot.tailnetUp))
        }

        return candidates.enumerated().map { offset, base -> (offset: Int, ranking: CandidateRanking) in
            let detail = evaluate(base)
            return (offset, CandidateRanking(
                base: base, role: detail.role, onLink: detail.onLink,
                score: detail.score, demoted: demoted.contains(base)
            ))
        }
        .sorted { lhs, rhs in
            if lhs.ranking.demoted != rhs.ranking.demoted { return !lhs.ranking.demoted }
            if lhs.ranking.score != rhs.ranking.score { return lhs.ranking.score > rhs.ranking.score }
            return lhs.offset < rhs.offset
        }
        .map(\.ranking)
    }

    /// Orders candidate base URLs from most to least reachable — `ranking` without the
    /// scoring detail. A no-op for single-URL instances.
    static func orderedBases(
        _ candidates: [String],
        snapshot: NetworkSnapshot,
        demoted: Set<String> = [],
        resolved: [String: ResolvedHost] = [:]
    ) -> [String] {
        ranking(candidates, snapshot: snapshot, demoted: demoted, resolved: resolved).map(\.base)
    }
}
