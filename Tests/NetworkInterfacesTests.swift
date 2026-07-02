import Network
import Testing
import Darwin
import Foundation

// Validates the proactive instance-URL selector in Ruddarr/Services/NetworkInterfaces.swift,
// which replaces timeout-based fallback by reading the device's own interface table.
// These tests exercise the pure pieces — Tailscale/CGNAT classification, on-link subnet
// math, and the deterministic candidate ordering — including the failure modes the design
// must get right: carrier-grade-NAT false positives and overlapping private subnets.
struct NetworkInterfacesTests {
    private func ipv4(_ string: String) -> UInt32 {
        NetworkInterfaces.parseIPv4(string)!
    }

    private func subnet(_ address: String, _ maskBits: UInt32) -> IPv4Subnet {
        let mask: UInt32 = maskBits == 0 ? 0 : (0xFFFF_FFFF << (32 - maskBits))
        return IPv4Subnet(address: ipv4(address), mask: mask)
    }

    private func ipv6(_ string: String) -> in6_addr {
        var address = in6_addr()
        _ = string.withCString { inet_pton(AF_INET6, $0, &address) }
        return address
    }

    private func subnet6(_ address: String, _ prefix: Int) -> IPv6Subnet {
        IPv6Subnet(address: NetworkInterfaces.ipv6Bytes(ipv6(address)), prefix: prefix)
    }

    // MARK: - CGNAT / Tailscale range

    @Test func recognizesCarrierGradeNATRange() {
        #expect(NetworkInterfaces.isCarrierGradeNAT(ipv4("100.64.0.0")))
        #expect(NetworkInterfaces.isCarrierGradeNAT(ipv4("100.64.0.1")))
        #expect(NetworkInterfaces.isCarrierGradeNAT(ipv4("100.100.50.7")))
        #expect(NetworkInterfaces.isCarrierGradeNAT(ipv4("100.127.255.255")))
    }

    @Test func excludesAddressesOutsideCGNATRange() {
        #expect(!NetworkInterfaces.isCarrierGradeNAT(ipv4("100.63.255.255"))) // just below
        #expect(!NetworkInterfaces.isCarrierGradeNAT(ipv4("100.128.0.0")))    // just above
        #expect(!NetworkInterfaces.isCarrierGradeNAT(ipv4("99.64.0.1")))
        #expect(!NetworkInterfaces.isCarrierGradeNAT(ipv4("10.0.0.1")))
    }

    // MARK: - Private IPv4

    @Test func recognizesPrivateRanges() {
        for host in ["10.0.0.1", "10.255.255.255", "172.16.0.1", "172.31.255.255",
                     "192.168.0.1", "192.168.1.50", "169.254.1.1", "127.0.0.1"] {
            #expect(NetworkInterfaces.isPrivateV4(ipv4(host)), "expected \(host) private")
        }
    }

    @Test func excludesPublicAndCGNATFromPrivate() {
        for host in ["8.8.8.8", "1.1.1.1", "172.15.0.1", "172.32.0.1", "100.64.0.1"] {
            #expect(!NetworkInterfaces.isPrivateV4(ipv4(host)), "expected \(host) not private")
        }
    }

    // MARK: - Host role classification

    @Test func classifiesHostsByRole() {
        #expect(NetworkInterfaces.role(forHost: "10.0.1.5") == .lan)
        #expect(NetworkInterfaces.role(forHost: "192.168.1.50") == .lan)
        #expect(NetworkInterfaces.role(forHost: "172.16.4.4") == .lan)
        #expect(NetworkInterfaces.role(forHost: "nas.local") == .lan)
        #expect(NetworkInterfaces.role(forHost: "fd00::1") == .lan)
        #expect(NetworkInterfaces.role(forHost: "fe80::1") == .lan)

        #expect(NetworkInterfaces.role(forHost: "100.64.0.3") == .tailscale)
        #expect(NetworkInterfaces.role(forHost: "server.tailnet.ts.net") == .tailscale)
        #expect(NetworkInterfaces.role(forHost: "fd7a:115c:a1e0::1") == .tailscale)

        #expect(NetworkInterfaces.role(forHost: "1.2.3.4") == .remote)
        #expect(NetworkInterfaces.role(forHost: "radarr.example.com") == .remote)
        #expect(NetworkInterfaces.role(forHost: "home.duckdns.org") == .remote)
    }

    @Test func extractsHostFromBaseURL() {
        #expect(NetworkInterfaces.host(of: "https://10.0.0.5:7878") == "10.0.0.5")
        #expect(NetworkInterfaces.host(of: "http://nas.local") == "nas.local")
        #expect(NetworkInterfaces.host(of: "http://nas.local.:7878") == "nas.local") // FQDN root dot stripped
        #expect(NetworkInterfaces.host(of: "http://[fd7a:115c:a1e0::1]:8989") == "fd7a:115c:a1e0::1")
        #expect(NetworkInterfaces.host(of: "not a url") == nil)
    }

    // MARK: - On-link subnet math

    @Test func subnetMembershipUsesMask() {
        let lan = subnet("192.168.1.0", 24)
        #expect(lan.contains(ipv4("192.168.1.50")))
        #expect(lan.contains(ipv4("192.168.1.1")))
        #expect(!lan.contains(ipv4("192.168.2.50")))
        #expect(!lan.contains(ipv4("10.0.0.50")))
    }

    @Test func snapshotOnLinkChecksEveryInterface() {
        let snapshot = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("10.0.0.0", 24), subnet("192.168.5.0", 24)])
        #expect(snapshot.isOnLink(ipv4("192.168.5.10")))
        #expect(snapshot.isOnLink(ipv4("10.0.0.7")))
        #expect(!snapshot.isOnLink(ipv4("192.168.1.10")))
    }

    // MARK: - Candidate ordering (the actual selection)

    private let lanURL = "http://192.168.1.50:7878"
    private let tailscaleURL = "https://box.tailnet.ts.net"
    private let remoteURL = "https://remote.example.com"

    @Test func prefersOnLinkLANWhenHome() {
        // Home: on the server's subnet, tailnet also up — raw LAN should win.
        let home = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let ordered = NetworkInterfaces.orderedBases([lanURL, tailscaleURL, remoteURL], snapshot: home)
        #expect(ordered.first == lanURL)
    }

    @Test func prefersTailscaleWhenAwayAndLANNotOnLink() {
        // Away on a foreign network (different subnet) with the tunnel up: the LAN URL is
        // not on-link, so Tailscale is chosen — no timeout, no probe.
        let away = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("10.20.30.0", 24)])
        let ordered = NetworkInterfaces.orderedBases([lanURL, tailscaleURL, remoteURL], snapshot: away)
        #expect(ordered.first == tailscaleURL)
    }

    @Test func prefersRemoteWhenTailscaleDown() {
        // Cellular, no tailnet: a *.ts.net URL must never be picked (it would NXDOMAIN).
        let cellular = NetworkSnapshot(tailnetUp: false, lanV4: [])
        let ordered = NetworkInterfaces.orderedBases([lanURL, tailscaleURL, remoteURL], snapshot: cellular)
        #expect(ordered.first == remoteURL)
        #expect(ordered.last == tailscaleURL)
    }

    @Test func demotedBaseSinksEvenWhenOnLink() {
        // Self-correct: after the on-link LAN URL just failed, it is demoted and the next
        // request proactively moves to the next-best candidate.
        let home = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let ordered = NetworkInterfaces.orderedBases(
            [lanURL, tailscaleURL, remoteURL], snapshot: home, demoted: [lanURL]
        )
        #expect(ordered.first == tailscaleURL)
        #expect(ordered.last == lanURL)
    }

    @Test func keepsCanonicalOrderOnTies() {
        // Two remote URLs (equal score) keep their given order — canonical first.
        let snapshot = NetworkSnapshot(tailnetUp: false, lanV4: [])
        let a = "https://a.example.com"
        let b = "https://b.example.com"
        #expect(NetworkInterfaces.orderedBases([a, b], snapshot: snapshot) == [a, b])
        #expect(NetworkInterfaces.orderedBases([b, a], snapshot: snapshot) == [b, a])
    }

    @Test func prefersDotLocalOverTailscaleAndRemoteWhenHome() {
        // `.local` is link-only and never resolved; with a LAN up it must outrank both a
        // tunnel (up) and remote, so the home mDNS name is the pick.
        let localURL = "http://nas.local:7878"
        let home = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let ordered = NetworkInterfaces.orderedBases([remoteURL, tailscaleURL, localURL], snapshot: home)
        #expect(ordered.first == localURL)
    }

    @Test func dotLocalWithTrailingRootDotStillPrefersLAN() {
        // `nas.local.` (FQDN root dot) must normalize to `nas.local`: classified LAN and
        // preferred on-link at home, not misread as remote nor sent to getaddrinfo.
        let localDot = "http://nas.local.:7878"
        let home = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let ordered = NetworkInterfaces.orderedBases([remoteURL, tailscaleURL, localDot], snapshot: home)
        #expect(ordered.first == localDot)
    }

    @Test func dotLocalLosesToRemoteWhenNoLAN() {
        // Away with no LAN interface, a `.local` name can't resolve, so it must never be
        // chosen over a reachable remote URL.
        let localURL = "http://nas.local:7878"
        let cellular = NetworkSnapshot(tailnetUp: false, lanV4: [])
        let ordered = NetworkInterfaces.orderedBases([localURL, remoteURL], snapshot: cellular)
        #expect(ordered.first == remoteURL)
        #expect(ordered.last == localURL)
    }

    @Test func prefersLoopbackOverRemoteEvenWithNoLAN() {
        // A server on this device (127.0.0.1 / ::1) is always reachable and must beat a
        // remote URL on every network, LAN up or not.
        let cellular = NetworkSnapshot(tailnetUp: false, lanV4: [])
        #expect(NetworkInterfaces.orderedBases(["https://remote.example.com", "http://127.0.0.1:7878"], snapshot: cellular).first == "http://127.0.0.1:7878")
        #expect(NetworkInterfaces.orderedBases(["https://remote.example.com", "http://[::1]:7878"], snapshot: cellular).first == "http://[::1]:7878")
    }

    @Test func hostlessCandidateSinksToBack() {
        // A malformed base (no host) scores 0 and must rank below any real candidate.
        let snapshot = NetworkSnapshot(tailnetUp: false, lanV4: [])
        let ordered = NetworkInterfaces.orderedBases(["not a url", remoteURL], snapshot: snapshot)
        #expect(ordered.first == remoteURL)
        #expect(ordered.last == "not a url")
    }

    @Test func demotedCandidatesKeepCanonicalOrderAmongThemselves() {
        // Two demoted on-link bases both sink behind the healthy remote, but keep canonical
        // order between them.
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        let a = "http://192.168.1.10:7878"
        let b = "http://192.168.1.11:7878"
        #expect(NetworkInterfaces.orderedBases([a, b, remoteURL], snapshot: home, demoted: [a, b]) == [remoteURL, a, b])
    }

    @Test func localNetworkDeniedDropsLANButKeepsLoopback() {
        // Local Network denied: an on-link LAN URL would only time out, so a routable remote
        // must win instead of being preferred.
        let denied = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)], localNetworkDenied: true)
        #expect(NetworkInterfaces.orderedBases(["http://192.168.1.50:7878", remoteURL], snapshot: denied).first == remoteURL)
        // Loopback is not gated by the Local Network permission, so it stays preferred.
        #expect(NetworkInterfaces.orderedBases([remoteURL, "http://127.0.0.1:7878"], snapshot: denied).first == "http://127.0.0.1:7878")
    }

    // MARK: - Resolved-host classification (split-horizon DNS, IPv4 + IPv6)

    @Test func classifiesResolvedOnLinkIPv4AsLAN() {
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        let resolved = NetworkInterfaces.classify(ipv4: [ipv4("192.168.1.50")], ipv6: [], snapshot: home)
        #expect(resolved == ResolvedHost(role: .lan, onLink: true))
    }

    @Test func classifiesResolvedOnLinkIPv6AsLAN() {
        // IPv6 does not NAT: a server sharing the device's /64 is reachable directly.
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [], lanV6: [subnet6("2001:db8:abcd:1::", 64)])
        let resolved = NetworkInterfaces.classify(ipv4: [], ipv6: [ipv6("2001:db8:abcd:1::50")], snapshot: home)
        #expect(resolved == ResolvedHost(role: .lan, onLink: true))
    }

    @Test func classifiesResolvedLoopbackAsOnLinkLAN() {
        // A name that resolves to loopback (e.g. `localhost`) is the server on this device —
        // on-link LAN, not off-link (which would lose to a remote URL) — on any network.
        let away = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("10.20.30.0", 24)])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("127.0.0.1")], ipv6: [], snapshot: away) == ResolvedHost(role: .lan, onLink: true))
        #expect(NetworkInterfaces.classify(ipv4: [], ipv6: [ipv6("::1")], snapshot: away) == ResolvedHost(role: .lan, onLink: true))
    }

    @Test func classifiesOffLinkPrivateAsLANNotOnLink() {
        // Away: the name's record is a private address for some *other* network.
        let away = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("10.20.30.0", 24)], lanV6: [subnet6("2001:db8:1::", 64)])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("192.168.1.50")], ipv6: [], snapshot: away) == ResolvedHost(role: .lan, onLink: false))
        #expect(NetworkInterfaces.classify(ipv4: [], ipv6: [ipv6("fd12:3456::1")], snapshot: away) == ResolvedHost(role: .lan, onLink: false))
    }

    @Test func classifiesTailscaleAddresses() {
        let snapshot = NetworkSnapshot(tailnetUp: true, lanV4: [])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("100.100.1.1")], ipv6: [], snapshot: snapshot).role == .tailscale)
        #expect(NetworkInterfaces.classify(ipv4: [], ipv6: [ipv6("fd7a:115c:a1e0::1")], snapshot: snapshot).role == .tailscale)
    }

    @Test func classifiesPublicAddressesAsRemote() {
        let snapshot = NetworkSnapshot(tailnetUp: false, lanV4: [])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("1.2.3.4")], ipv6: [], snapshot: snapshot) == ResolvedHost(role: .remote, onLink: false))
        #expect(NetworkInterfaces.classify(ipv4: [], ipv6: [ipv6("2606:4700::1111")], snapshot: snapshot) == ResolvedHost(role: .remote, onLink: false))
    }

    @Test func classifyPrefersOnLinkAcrossMultipleRecords() {
        // Multi-record A/AAAA: an on-link address wins regardless of position among public or
        // off-link siblings — the split-horizon "points home" case.
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("1.2.3.4"), ipv4("192.168.1.50")], ipv6: [], snapshot: home) == ResolvedHost(role: .lan, onLink: true))
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("192.168.1.50"), ipv4("1.2.3.4")], ipv6: [], snapshot: home) == ResolvedHost(role: .lan, onLink: true))
    }

    @Test func classifyPrecedenceTailscaleThenOffLinkPrivateThenRemote() {
        // No on-link record: CGNAT (tailnet) outranks a merely-private off-link address, which
        // in turn outranks a public one.
        let away = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("10.20.30.0", 24)])
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("192.168.1.50"), ipv4("100.100.1.1")], ipv6: [], snapshot: away).role == .tailscale)
        #expect(NetworkInterfaces.classify(ipv4: [ipv4("1.2.3.4"), ipv4("192.168.1.50")], ipv6: [], snapshot: away) == ResolvedHost(role: .lan, onLink: false))
    }

    // MARK: - Resolution-aware ordering (one local domain, one remote domain)

    private let localDomain = "https://radarr.examplehomelab.com"
    private let remoteDomain = "https://radarr.external.com"

    @Test func resolvedLocalDomainBeatsRemoteWhenOnLink() {
        // Home: the local name resolves to an on-link IP; the tunnel name stays remote.
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        let resolved = [
            "radarr.examplehomelab.com": ResolvedHost(role: .lan, onLink: true),
            "radarr.external.com": ResolvedHost(role: .remote, onLink: false),
        ]
        let ordered = NetworkInterfaces.orderedBases([localDomain, remoteDomain], snapshot: home, resolved: resolved)
        #expect(ordered.first == localDomain)
    }

    @Test func resolvedLocalDomainSinksWhenAwayAndOffLink() {
        // Away: the local name still resolves (public DNS) to its private IP, but it's no
        // longer on-link — so the routable remote name wins, with no timeout, no probe.
        let away = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("172.16.9.0", 24)])
        let resolved = [
            "radarr.examplehomelab.com": ResolvedHost(role: .lan, onLink: false),
            "radarr.external.com": ResolvedHost(role: .remote, onLink: false),
        ]
        let ordered = NetworkInterfaces.orderedBases([localDomain, remoteDomain], snapshot: away, resolved: resolved)
        #expect(ordered.first == remoteDomain)
        #expect(ordered.last == localDomain)
    }

    @Test func unresolvedHostnamesKeepCanonicalOrder() {
        // Before any lookup lands, two hostnames are lexically both `.remote`: keep the
        // canonical URL first and let resolution / self-correct refine.
        let snapshot = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        #expect(NetworkInterfaces.orderedBases([localDomain, remoteDomain], snapshot: snapshot) == [localDomain, remoteDomain])
    }

    @Test func prefersOnLinkIPv6LiteralWhenHome() {
        // A literal IPv6 LAN URL is on-link-tested too, not just classified lexically.
        let home = NetworkSnapshot(tailnetUp: false, lanV4: [], lanV6: [subnet6("fd00:1234::", 64)])
        let lan6 = "http://[fd00:1234::5]:7878"
        #expect(NetworkInterfaces.orderedBases([remoteURL, lan6], snapshot: home).first == lan6)
    }

    // MARK: - Ranking detail (backs the bug-report breakdown)

    @Test func rankingReportsRoleScoreAndDemotion() {
        let home = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let ranked = NetworkInterfaces.ranking([lanURL, tailscaleURL, remoteURL], snapshot: home, demoted: [lanURL])

        // Demoted on-link LAN keeps its true role/score but is forced to the back.
        let lan = ranked.first { $0.base == lanURL }
        #expect(lan?.role == .lan)
        #expect(lan?.onLink == true)
        #expect(lan?.score == 100)
        #expect(lan?.demoted == true)
        #expect(ranked.last?.base == lanURL)

        // Tailscale (tunnel up) now wins; remote stays the routable middle.
        #expect(ranked.first?.base == tailscaleURL)
        #expect(ranked.first?.score == 90)
        #expect(ranked.contains { $0.base == remoteURL && $0.role == .remote && $0.score == 50 })
    }

    // MARK: - Interface contribution (the CGNAT-vs-Tailscale wall)

    @Test func classifyV4TailnetNeedsUtunAndCGNAT() {
        // The load-bearing conjunction: only a `utun` carrying a CGNAT address is the tailnet.
        #expect(NetworkSnapshot.classifyV4(name: "utun3", flags: 0, address: ipv4("100.100.3.7"), mask: 0xFFFF_FFFF) == .tailnet)
        // CGNAT on a carrier interface (pdp) must NOT be read as the tailnet.
        #expect(NetworkSnapshot.classifyV4(name: "pdp_ip0", flags: 0, address: ipv4("100.100.3.7"), mask: 0xFFFF_FFFF) == .ignored)
        // A non-CGNAT tunnel is not the tailnet either.
        #expect(NetworkSnapshot.classifyV4(name: "utun0", flags: 0, address: ipv4("10.0.0.1"), mask: 0xFF00_0000) == .ignored)
    }

    @Test func classifyV4RecordsOnlyRealEthernetLANs() {
        let en = NetworkSnapshot.classifyV4(name: "en0", flags: 0, address: ipv4("192.168.1.5"), mask: 0xFFFF_FF00)
        #expect(en == .lan(IPv4Subnet(address: ipv4("192.168.1.5"), mask: 0xFFFF_FF00)))
        // VM / bridge / AirDrop-style interfaces never masquerade as a LAN.
        #expect(NetworkSnapshot.classifyV4(name: "bridge100", flags: 0, address: ipv4("192.168.5.1"), mask: 0xFFFF_FF00) == .ignored)
        // A point-to-point `en` (tunnel) is excluded.
        #expect(NetworkSnapshot.classifyV4(name: "en5", flags: Int32(IFF_POINTOPOINT), address: ipv4("192.168.1.5"), mask: 0xFFFF_FF00) == .ignored)
    }

    @Test func classifyV6TailnetNeedsUtunAndTailscaleULA() {
        let ula = NetworkInterfaces.ipv6Bytes(ipv6("fd7a:115c:a1e0::1"))
        #expect(NetworkSnapshot.classifyV6(name: "utun3", flags: 0, address: ula, prefix: 128) == .tailnet)
        // A different ULA on a utun (e.g. NetBird) is not Tailscale.
        #expect(NetworkSnapshot.classifyV6(name: "utun3", flags: 0, address: NetworkInterfaces.ipv6Bytes(ipv6("fd00:dead::1")), prefix: 128) == .ignored)
    }

    @Test func classifyV6RecordsGlobalEthernetPrefixSkipsLinkLocal() {
        let global = NetworkInterfaces.ipv6Bytes(ipv6("2001:db8:abcd:1::5"))
        #expect(NetworkSnapshot.classifyV6(name: "en0", flags: 0, address: global, prefix: 64) == .lan(IPv6Subnet(address: global, prefix: 64)))
        // Link-local on en* is skipped (unaddressable without a zone id).
        #expect(NetworkSnapshot.classifyV6(name: "en0", flags: 0, address: NetworkInterfaces.ipv6Bytes(ipv6("fe80::1")), prefix: 64) == .ignored)
    }

    // MARK: - Fingerprint

    @Test func fingerprintIsStablePerNetwork() {
        let a = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let b = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("192.168.1.0", 24)])
        let c = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.1.0", 24)])
        let d = NetworkSnapshot(tailnetUp: true, lanV4: [subnet("10.0.0.0", 24)])

        #expect(a.fingerprint == b.fingerprint)
        #expect(a.fingerprint != c.fingerprint) // tailnet toggled
        #expect(a.fingerprint != d.fingerprint) // different subnet
    }

    @Test func fingerprintIgnoresIPv6PrivacyAddressRotation() {
        // Two addresses in the same /64 (RFC 4941 temporary-address rotation, or Wi-Fi +
        // Ethernet on one LAN) collapse to a single masked prefix, so the fingerprint holds.
        let single = NetworkSnapshot(tailnetUp: false, lanV6: [subnet6("2001:db8:abcd:1::1111", 64)])
        let rotated = NetworkSnapshot(tailnetUp: false, lanV6: [
            subnet6("2001:db8:abcd:1::1111", 64),
            subnet6("2001:db8:abcd:1::2222", 64),
        ])
        #expect(single.fingerprint == rotated.fingerprint)

        // A genuinely different /64 must still change it.
        let other = NetworkSnapshot(tailnetUp: false, lanV6: [subnet6("2001:db8:abcd:2::1111", 64)])
        #expect(single.fingerprint != other.fingerprint)
    }

    // MARK: - Live capture smoke test

    @Test func captureProducesWellFormedFingerprint() {
        // capture() reads the live interface table; rather than assert machine specifics (which
        // is flaky on CI), require only that its fingerprint is well-formed — the token that
        // scopes demotions and resolutions.
        let fingerprint = NetworkSnapshot.capture().fingerprint
        #expect(fingerprint.hasPrefix("ts:"))
        #expect(fingerprint.contains("|lan4:"))
        #expect(fingerprint.contains("|lan6:"))
    }
}
