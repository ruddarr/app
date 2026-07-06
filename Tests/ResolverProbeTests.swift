import Testing
import Foundation

// Exercises the off-link probe machinery in ResolverRouting/NetworkInterfaces: which candidates
// qualify for a `/ping` probe, how claims are throttled and verdicts recorded per network, how a
// verified routed candidate re-ranks against remote and Tailscale — and the pure probe URL and
// response validation, which must never let a lookalike answer promote a stranger's address.
struct ResolverProbeTests {
    private func ipv4(_ string: String) -> UInt32 {
        NetworkInterfaces.parseIPv4(string)!
    }

    private func subnet(_ address: String, _ maskBits: UInt32) -> IPv4Subnet {
        let mask: UInt32 = maskBits == 0 ? 0 : (0xFFFF_FFFF << (32 - maskBits))
        return IPv4Subnet(address: ipv4(address), mask: mask)
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private var home: NetworkSnapshot { NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.10.0", 24)]) }
    private var away: NetworkSnapshot { NetworkSnapshot(tailnetUp: false, lanV4: []) }

    private let routed = "http://192.168.20.5:7878"
    private let remote = "https://radarr.example.com"

    // MARK: - Probe candidate selection

    @Test func probesOnlyOffLinkPrivateAddresses() {
        #expect(ResolverRouting.probeCandidate(routed, resolved: [:], snapshot: home))
        #expect(ResolverRouting.probeCandidate("http://[fd00:dead::5]:7878", resolved: [:], snapshot: home))

        #expect(!ResolverRouting.probeCandidate("http://192.168.10.5:7878", resolved: [:], snapshot: home)) // on-link
        #expect(!ResolverRouting.probeCandidate("http://127.0.0.1:7878", resolved: [:], snapshot: home))    // loopback
        #expect(!ResolverRouting.probeCandidate("http://169.254.4.2:7878", resolved: [:], snapshot: home))  // link-local
        #expect(!ResolverRouting.probeCandidate("http://100.100.3.7:7878", resolved: [:], snapshot: home))  // CGNAT
        #expect(!ResolverRouting.probeCandidate("http://[fd7a:115c:a1e0::7]:7878", resolved: [:], snapshot: home)) // tailnet
        #expect(!ResolverRouting.probeCandidate("http://8.8.8.8:7878", resolved: [:], snapshot: home))      // public
        #expect(!ResolverRouting.probeCandidate(remote, resolved: [:], snapshot: home))                     // unresolved name
        #expect(!ResolverRouting.probeCandidate("http://nas.local:7878", resolved: [:], snapshot: home))    // mDNS
    }

    @Test func probesHostnamesByWhereTheyResolve() {
        let offLink = ["radarr.example.com": ResolvedHost(role: .lan, onLink: false)]
        let onLink = ["radarr.example.com": ResolvedHost(role: .lan, onLink: true)]
        let loopback = ["radarr.example.com": ResolvedHost(role: .lan, onLink: false, isLoopback: true)]
        let tunnel = ["radarr.example.com": ResolvedHost(role: .tailscale, onLink: false)]

        #expect(ResolverRouting.probeCandidate(remote, resolved: offLink, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: onLink, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: loopback, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: tunnel, snapshot: home))
    }

    // MARK: - Claiming, throttling, recording

    @Test func claimRequiresALANAndThrottlesRetries() {
        var state = ResolverRouting.State()

        // No LAN → no router that could route into the server's VLAN → nothing to probe.
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: away, resolved: [:], now: t0).isEmpty)

        // Claimed once; an immediate retry sees it attempted <30s ago and skips.
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0) == [routed])
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0.addingTimeInterval(10)).isEmpty)

        // A failed probe is retried once the interval elapses since completion.
        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: false), now: t0.addingTimeInterval(2))
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0.addingTimeInterval(33)) == [routed])

        // A verified base is done for this network — never re-claimed.
        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.012), now: t0.addingTimeInterval(34))
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0.addingTimeInterval(300)).isEmpty)
    }

    @Test func recordProbeDropsResultsFromASupersededEpoch() {
        var state = ResolverRouting.State()
        state.epoch = 5

        ResolverRouting.recordProbe(&state, base: routed, epoch: 4, outcome: ProbeOutcome(reachable: true), now: t0)
        #expect(state.probeOutcomes.isEmpty)

        ResolverRouting.recordProbe(&state, base: routed, epoch: 5, outcome: ProbeOutcome(reachable: true), now: t0)
        #expect(state.probeOutcomes[routed] == ProbeOutcome(reachable: true))
    }

    @Test func fingerprintChangeForgetsVerdictsButKeepsThrottle() {
        var state = ResolverRouting.State()

        _ = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)
        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.01), now: t0)
        #expect(state.probeOutcomes[routed]?.reachable == true)

        // A different network drops the verdict (a foreign 192.168.20.5 is a different machine),
        // but the attempt throttle survives the flap, exactly like the DNS one.
        _ = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: away, fingerprint: away.fingerprint, now: t0.addingTimeInterval(1))
        #expect(state.probeOutcomes.isEmpty)
        #expect(state.probeAttemptedAt[routed] != nil)

        // Only a real network change clears the throttle too.
        ResolverRouting.networkChanged(&state)
        #expect(state.probeAttemptedAt.isEmpty)
    }

    // MARK: - Ranking with verdicts

    @Test func verifiedRoutedCandidateOutranksRemoteAndTunnel() {
        let candidates = [remote, routed]
        let verified = [routed: ProbeOutcome(reachable: true, latency: 0.012)]
        let failed = [routed: ProbeOutcome(reachable: false)]

        // Unverified or failed → remote stays first; verified → the routed VLAN address wins.
        #expect(NetworkInterfaces.orderedBases(candidates, snapshot: home) == [remote, routed])
        #expect(NetworkInterfaces.orderedBases(candidates, snapshot: home, probed: failed) == [remote, routed])
        #expect(NetworkInterfaces.orderedBases(candidates, snapshot: home, probed: verified) == [routed, remote])

        // Verified (95) beats a live tunnel (90), but never an on-link address (100).
        var tunnelUp = home
        tunnelUp.tailnetUp = true
        #expect(NetworkInterfaces.orderedBases(["https://box.ts.net", routed], snapshot: tunnelUp, probed: verified) == [routed, "https://box.ts.net"])
        #expect(NetworkInterfaces.orderedBases([routed, "http://192.168.10.5:7878"], snapshot: home, probed: verified).first == "http://192.168.10.5:7878")

        // A Local Network denial doesn't touch it: routed traffic goes to the gateway, not the
        // local broadcast domain, and the probe just proved it works.
        var denied = home
        denied.localNetworkDenied = true
        #expect(NetworkInterfaces.orderedBases(candidates, snapshot: denied, probed: verified) == [routed, remote])
    }

    @Test func registerClaimsProbesAndRanksWithVerdicts() {
        var state = ResolverRouting.State()

        let first = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)
        #expect(first.ordered == [remote, routed])
        #expect(first.probes == [routed])

        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.008), now: t0.addingTimeInterval(1))

        let second = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0.addingTimeInterval(2))
        #expect(second.ordered == [routed, remote])
        #expect(second.probes.isEmpty)
    }

    @Test func failoverFallsBackToVerifiedRoutedCandidate() {
        var state = ResolverRouting.State()

        _ = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)
        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.008), now: t0)

        let next = ResolverRouting.failover(
            &state, afterFailing: remote + "/api/v3/movie", candidates: [remote, routed],
            snapshot: home, fingerprint: home.fingerprint, now: t0.addingTimeInterval(1)
        )
        #expect(next == URL(string: routed + "/api/v3/movie"))
    }

    // MARK: - Probe URL and verdict

    @Test func probeURLStripsCredentialsAndAppendsPing() {
        #expect(ResolverRouting.probeURL(for: "http://user:pass@192.168.20.5:7878") == URL(string: "http://192.168.20.5:7878/ping"))
        #expect(ResolverRouting.probeURL(for: "https://nas.example.com/radarr") == URL(string: "https://nas.example.com/radarr/ping"))
        #expect(ResolverRouting.probeURL(for: "http://[fd00:dead::5]:7878") == URL(string: "http://[fd00:dead::5]:7878/ping"))
        #expect(ResolverRouting.probeURL(for: "not a url") == nil)
    }

    @Test func probeVerdictAcceptsOnlyAGenuinePingAnswer() {
        let ok = Data(#"{"status": "OK"}"#.utf8)
        let host = "192.168.20.5"

        #expect(ResolverRouting.probeVerdict(status: 200, finalHost: host, probedHost: host, body: ok))
        #expect(ResolverRouting.probeVerdict(status: 200, finalHost: host, probedHost: host, body: Data(#"{"status": "ok"}"#.utf8)))

        // Redirected elsewhere, HTML, lookalike JSON, or an error status → all refused.
        #expect(!ResolverRouting.probeVerdict(status: 200, finalHost: "radarr.example.com", probedHost: host, body: ok))
        #expect(!ResolverRouting.probeVerdict(status: 200, finalHost: nil, probedHost: host, body: ok))
        #expect(!ResolverRouting.probeVerdict(status: 200, finalHost: host, probedHost: host, body: Data("<html>portal</html>".utf8)))
        #expect(!ResolverRouting.probeVerdict(status: 200, finalHost: host, probedHost: host, body: Data(#"{"status": 1}"#.utf8)))
        #expect(!ResolverRouting.probeVerdict(status: 200, finalHost: host, probedHost: host, body: Data(#"{"health": "OK"}"#.utf8)))
        #expect(!ResolverRouting.probeVerdict(status: 500, finalHost: host, probedHost: host, body: ok))
        #expect(!ResolverRouting.probeVerdict(status: 302, finalHost: host, probedHost: host, body: ok))
    }
}
