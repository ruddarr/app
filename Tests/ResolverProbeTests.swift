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
        let linkLocal = ["radarr.example.com": ResolvedHost(role: .lan, onLink: false, isLinkLocal: true)]
        let tunnel = ["radarr.example.com": ResolvedHost(role: .tailscale, onLink: false)]

        #expect(ResolverRouting.probeCandidate(remote, resolved: offLink, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: onLink, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: loopback, snapshot: home))
        #expect(!ResolverRouting.probeCandidate(remote, resolved: linkLocal, snapshot: home)) // e.g. a stale name pointing at 169.254/fe80
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

    @Test func onLinkSiblingSuppressesProbes() {
        var state = ResolverRouting.State()
        let onLink = "http://192.168.10.5:7878"

        // A reachable on-link sibling (100) outranks any probe verdict (95), so the routed
        // candidate is not probed — and no throttle is stamped, so nothing delays the claim
        // once that changes.
        #expect(ResolverRouting.claimProbesNeeded(&state, [onLink, routed], snapshot: home, resolved: [:], now: t0).isEmpty)
        #expect(state.probeAttemptedAt.isEmpty)

        // Once the on-link sibling demotes (a request just failed), the probe matters at once.
        state.demotedUntil[onLink] = t0.addingTimeInterval(60)
        #expect(ResolverRouting.claimProbesNeeded(&state, [onLink, routed], snapshot: home, resolved: [:], now: t0) == [routed])
    }

    @Test func resolvedOnLinkSiblingSuppressesProbes() {
        var state = ResolverRouting.State()
        let resolved = ["radarr.example.com": ResolvedHost(role: .lan, onLink: true)]

        #expect(ResolverRouting.claimProbesNeeded(&state, [remote, routed], snapshot: home, resolved: resolved, now: t0).isEmpty)
    }

    @Test func localNetworkDenialLiftsTheOnLinkProbeSuppression() {
        var state = ResolverRouting.State()
        var denied = home
        denied.localNetworkDenied = true

        // Denied local network makes the on-link sibling unreachable (score 30), so a routed
        // verdict (95) could win the ranking — the probe is claimed after all.
        #expect(ResolverRouting.claimProbesNeeded(&state, ["http://192.168.10.5:7878", routed], snapshot: denied, resolved: [:], now: t0) == [routed])
    }

    @Test func rankReadsWithoutClaimingLookupsOrProbes() {
        var state = ResolverRouting.State()

        let ordered = ResolverRouting.rank(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)

        #expect(ordered == [remote, routed])
        #expect(state.resolveAttemptedAt.isEmpty && state.resolveInFlight.isEmpty)
        #expect(state.probeAttemptedAt.isEmpty && state.probeInFlight.isEmpty)
    }

    @Test func inFlightLookupIsNeverStackedByANetworkChange() {
        var state = ResolverRouting.State()

        #expect(ResolverRouting.claimHostsNeedingResolution(&state, [remote], now: t0) == ["radarr.example.com"])

        // The change wipes the retry throttle, but the running lookup must not be re-dispatched.
        ResolverRouting.networkChanged(&state)
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, [remote], now: t0.addingTimeInterval(1)).isEmpty)

        // Completion clears the guard even though the stale result is dropped.
        ResolverRouting.recordResolution(&state, host: "radarr.example.com", epoch: 0, resolved: ResolvedHost(role: .lan, onLink: true), now: t0.addingTimeInterval(2))
        #expect(state.resolvedHosts.isEmpty)
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, [remote], now: t0.addingTimeInterval(3)) == ["radarr.example.com"])
    }

    @Test func inFlightProbeIsNeverStackedByANetworkChange() {
        var state = ResolverRouting.State()

        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0) == [routed])

        ResolverRouting.networkChanged(&state)
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0.addingTimeInterval(1)).isEmpty)

        ResolverRouting.recordProbe(&state, base: routed, epoch: 0, outcome: ProbeOutcome(reachable: true), now: t0.addingTimeInterval(2))
        #expect(state.probeOutcomes.isEmpty)
        #expect(ResolverRouting.claimProbesNeeded(&state, [routed], snapshot: home, resolved: [:], now: t0.addingTimeInterval(3)) == [routed])
    }

    @Test func recordProbeDropsResultsFromASupersededEpoch() {
        var state = ResolverRouting.State()
        state.epoch = 5

        ResolverRouting.recordProbe(&state, base: routed, epoch: 4, outcome: ProbeOutcome(reachable: true), now: t0)
        #expect(state.probeOutcomes.isEmpty)

        ResolverRouting.recordProbe(&state, base: routed, epoch: 5, outcome: ProbeOutcome(reachable: true), now: t0)
        #expect(state.probeOutcomes[routed] == ProbeOutcome(reachable: true))
    }

    @Test func fingerprintChangeForgetsVerdictsAndReprobesAtOnce() {
        var state = ResolverRouting.State()

        _ = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)
        ResolverRouting.recordProbe(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.01), now: t0)
        #expect(state.probeOutcomes[routed]?.reachable == true)

        // A different network drops the verdict (a foreign 192.168.20.5 is a different machine)
        // AND the probe throttle: the wiped verdict must be re-earnable at once, or selection
        // blacks out (95 → 30) for the whole retry interval on every fingerprint swing.
        let otherLAN = NetworkSnapshot(tailnetUp: false, lanV4: [subnet("192.168.30.0", 24)])
        let swung = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: otherLAN, fingerprint: otherLAN.fingerprint, now: t0.addingTimeInterval(1))
        #expect(state.probeOutcomes.isEmpty)
        #expect(swung.probes == [routed])

        // The DNS throttle is different — `getaddrinfo` is unbounded, so it survives the swing.
        state.resolveAttemptedAt["radarr.example.com"] = t0
        _ = ResolverRouting.register(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0.addingTimeInterval(2))
        #expect(state.resolveAttemptedAt["radarr.example.com"] != nil)

        // A real network change clears both throttles.
        ResolverRouting.networkChanged(&state)
        #expect(state.probeAttemptedAt.isEmpty)
        #expect(state.resolveAttemptedAt.isEmpty)
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

    // MARK: - Browser-facing web checks

    @Test func webChecksClaimEveryCandidateOnAnyNetwork() {
        var state = ResolverRouting.State()

        // Unlike probes: no LAN needed and no on-link suppression — "can a browser open this?"
        // is just as meaningful on cellular, and it has to be answered for every candidate.
        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote, routed], now: t0) == [remote, routed])
    }

    @Test func webChecksThrottleAndReCheckVerifiedBases() {
        var state = ResolverRouting.State()

        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0) == [remote])

        // In flight, then recently attempted → skipped both times.
        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0.addingTimeInterval(1)).isEmpty)
        ResolverRouting.recordWebCheck(&state, base: remote, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.02), now: t0.addingTimeInterval(2))
        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0.addingTimeInterval(10)).isEmpty)

        // A verified base IS re-checked once the interval elapses — the web button tracks
        // reachability, so an instance that went down stops counting without a network change.
        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0.addingTimeInterval(33)) == [remote])
    }

    @Test func staleWebCheckIsDroppedButClearsItsInFlightGuard() {
        var state = ResolverRouting.State()

        _ = ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0)
        let dispatched = state.epoch

        ResolverRouting.networkChanged(&state)
        ResolverRouting.recordWebCheck(&state, base: remote, epoch: dispatched, outcome: ProbeOutcome(reachable: true), now: t0.addingTimeInterval(3))

        // The verdict belonged to the old network, so it is discarded — and because the throttle
        // went with it, the next claim re-checks at once rather than waiting out the interval.
        #expect(state.webOutcomes[remote] == nil)
        #expect(state.webInFlight.isEmpty)
        #expect(ResolverRouting.claimWebChecksNeeded(&state, [remote], now: t0.addingTimeInterval(4)) == [remote])
    }

    @Test func networkChangeDropsWebVerdicts() {
        var state = ResolverRouting.State()

        ResolverRouting.recordWebCheck(&state, base: remote, epoch: state.epoch, outcome: ProbeOutcome(reachable: true), now: t0)
        #expect(state.webOutcomes[remote]?.reachable == true)

        ResolverRouting.networkChanged(&state)

        // A URL a browser could open at home must never vouch for itself on cellular.
        #expect(state.webOutcomes.isEmpty)
        #expect(state.webAttemptedAt.isEmpty)
    }

    @Test func webVerdictsNeverMoveTheAppsOwnRouting() {
        var state = ResolverRouting.State()

        ResolverRouting.recordWebCheck(&state, base: routed, epoch: state.epoch, outcome: ProbeOutcome(reachable: true, latency: 0.01), now: t0)

        // Ranking reads `probeOutcomes` alone, so a check made for the UI cannot promote a
        // candidate the routing probe never verified.
        let ordered = ResolverRouting.rank(&state, candidates: [remote, routed], snapshot: home, fingerprint: home.fingerprint, now: t0)
        #expect(ordered == [remote, routed])
    }

    @Test func webSelectionPrefersVerifiedOverAnswered() {
        let verdicts = [
            remote: ProbeOutcome(reachable: false, answered: true),
            routed: ProbeOutcome(reachable: true, latency: 0.01),
        ]

        // A genuine `/ping` outranks a mere answer, even from a better-ranked candidate.
        #expect(ResolverRouting.webSelection([remote, routed], outcomes: verdicts) == routed)
    }

    @Test func webSelectionKeepsAnsweredHostsOpenable() {
        // Safari may hold a session the unauthenticated check cannot see, so a host that
        // answered — a 403, a login page, an identity-provider redirect — is still offered.
        let verdicts = [
            remote: ProbeOutcome(reachable: false, answered: true),
            routed: ProbeOutcome(reachable: false),
        ]

        #expect(ResolverRouting.webSelection([routed, remote], outcomes: verdicts) == remote)

        // Only when nothing answers anywhere is there no URL — the disabled web button.
        #expect(ResolverRouting.webSelection([routed], outcomes: [routed: ProbeOutcome(reachable: false)]) == nil)
        #expect(ResolverRouting.webSelection([remote], outcomes: [:]) == nil)
    }
}
