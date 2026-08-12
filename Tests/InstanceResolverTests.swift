import Testing
import Foundation

// Exercises the pure routing / self-correction state machine (`ResolverRouting`) that backs
// `InstanceResolver`. Snapshots and the clock are injected, so every transition is deterministic.
struct InstanceResolverTests {
    private let a = "https://a.example.com"
    private let b = "https://b.example.com"
    private let fingerprint = "ts:false|lan4:|lan6:"
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let away = NetworkSnapshot(tailnetUp: false, lanV4: [])

    // MARK: - matchingBase path/port boundaries

    @Test func matchingBaseRespectsPathAndPortBoundaries() {
        let candidates = ["https://nas.example.com", "https://nas.example.com/radarr"]
        // A real request path boundary matches, and the longest prefix wins.
        #expect(ResolverRouting.matchingBase(candidates, for: "https://nas.example.com/api/v3/movie") == "https://nas.example.com")
        #expect(ResolverRouting.matchingBase(candidates, for: "https://nas.example.com/radarr/api/v3/movie") == "https://nas.example.com/radarr")
        // A query-string boundary matches too.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com"], for: "https://nas.example.com?x=1") == "https://nas.example.com")
        // A different port is a *sibling* origin, not this base.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com"], for: "https://nas.example.com:8989/api/v3/series") == nil)
        // `/radarr-4k` must not be swallowed by the `/radarr` base.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com/radarr"], for: "https://nas.example.com/radarr-4k/api") == nil)
    }

    // MARK: - Self-correction loop

    @Test func selfCorrectsThroughFailoverAndRecovers() {
        var state = ResolverRouting.State()

        // Two remote candidates rank as a tie → canonical order.
        let first = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0)
        #expect(first.ordered == [a, b])

        // `a` fails on a request → demoted; the next-best sibling is returned with the path
        // re-attached (and on the boundary, not a fabricated port).
        let next = ResolverRouting.failover(&state, afterFailing: a + "/api/v3/movie", candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0)
        #expect(next == URL(string: b + "/api/v3/movie"))

        // The next selection prefers `b` while `a` stays demoted.
        let second = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0)
        #expect(second.ordered == [b, a])

        // `a` responds again → its demotion clears and canonical order returns.
        ResolverRouting.noteSuccess(&state, for: a + "/api/v3/movie", candidates: [a, b])
        let third = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0)
        #expect(third.ordered == [a, b])
    }

    @Test func failoverReturnsNilWhenNothingElseIsReachable() {
        var state = ResolverRouting.State()
        // A URL that matches none of the candidates → no failover.
        #expect(ResolverRouting.failover(&state, afterFailing: "https://other.example.com/api", candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0) == nil)
        // A single-candidate instance has no sibling to fail over to.
        #expect(ResolverRouting.failover(&state, afterFailing: a + "/api/v3/movie", candidates: [a], snapshot: away, fingerprint: fingerprint, now: t0) == nil)
    }

    @Test func failoverOnlyConsidersTheGivenInstancesCandidates() {
        var state = ResolverRouting.State()

        // Instance A sits at the domain root; single-URL instance B lives under a subpath. B's
        // failover is computed only from B's own candidates, so it can never demote or reach A —
        // the cross-instance capture that a shared URL registry allowed is structurally gone.
        let result = ResolverRouting.failover(&state, afterFailing: "https://nas/sonarr/api/v3/series", candidates: ["https://nas/sonarr"], snapshot: away, fingerprint: fingerprint, now: t0)
        #expect(result == nil)
        #expect(state.demotedUntil["https://nas"] == nil)
    }

    // MARK: - Network change + epoch guard

    @Test func networkChangedClearsDemotionsAndBumpsEpoch() {
        var state = ResolverRouting.State()
        state.fingerprint = fingerprint
        state.demotedUntil[a] = t0.addingTimeInterval(600)
        let before = state.epoch

        ResolverRouting.networkChanged(&state)

        #expect(state.epoch == before + 1)
        #expect(state.demotedUntil.isEmpty)
        #expect(state.fingerprint.isEmpty)
    }

    @Test func registerClearsCachesWhenTheFingerprintChanges() {
        var state = ResolverRouting.State()
        _ = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, now: t0)
        ResolverRouting.recordResolution(&state, host: "radarr.example.com", epoch: state.epoch, resolved: ResolvedHost(role: .lan, onLink: true), now: t0)
        state.demotedUntil[a] = t0.addingTimeInterval(600)

        // A different network drops everything learned on the old one.
        _ = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: "ts:true|lan4:|lan6:", now: t0)
        #expect(state.demotedUntil.isEmpty)
        #expect(state.resolvedHosts.isEmpty)
        #expect(state.fingerprint == "ts:true|lan4:|lan6:")
    }

    @Test func dnsRetryThrottleSurvivesAFingerprintFlap() {
        var state = ResolverRouting.State()
        state.fingerprint = fingerprint
        state.resolveAttemptedAt["radarr.example.com"] = t0

        // A flap to a different fingerprint clears resolutions/demotions but must keep the retry
        // throttle, so the host isn't re-stormed to getaddrinfo on every swing (A11).
        _ = ResolverRouting.register(&state, candidates: ["https://radarr.example.com"], snapshot: away, fingerprint: "ts:true|lan4:|lan6:", now: t0.addingTimeInterval(5))
        #expect(state.resolveAttemptedAt["radarr.example.com"] == t0)
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, ["https://radarr.example.com"], now: t0.addingTimeInterval(10)).isEmpty)

        // Only a real network change clears the throttle, allowing an immediate re-resolve.
        ResolverRouting.networkChanged(&state)
        #expect(state.resolveAttemptedAt.isEmpty)
    }

    @Test func recordResolutionDropsResultFromASupersededEpoch() {
        var state = ResolverRouting.State()
        state.epoch = 5
        let host = "radarr.example.com"
        let onLink = ResolvedHost(role: .lan, onLink: true)

        // A lookup dispatched before the caches were cleared (epoch 4) must not land now (epoch 5).
        ResolverRouting.recordResolution(&state, host: host, epoch: 4, resolved: onLink, now: t0)
        #expect(state.resolvedHosts.isEmpty)

        // The current epoch writes through.
        ResolverRouting.recordResolution(&state, host: host, epoch: 5, resolved: onLink, now: t0)
        #expect(state.resolvedHosts[host] == onLink)
    }

    // MARK: - Demotion TTL

    @Test func activeDemotionsExpire() {
        var state = ResolverRouting.State()
        state.demotedUntil[a] = t0.addingTimeInterval(-1)   // already expired
        state.demotedUntil[b] = t0.addingTimeInterval(100)  // still active

        let demoted = ResolverRouting.activeDemotions(&state, now: t0)

        #expect(demoted == [b])                       // only the active one
        #expect(state.demotedUntil[a] == nil)         // expired entry pruned from state
    }

    // MARK: - Lookup claiming

    @Test func claimHostsResolvesEachHostOnceAndSkipsNonResolvables() {
        var state = ResolverRouting.State()

        // A plain hostname is claimed once; the immediate retry sees it attempted <30s ago and skips.
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, ["https://radarr.example.com"], now: t0) == ["radarr.example.com"])
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, ["https://radarr.example.com"], now: t0).isEmpty)

        // IP literals, `.local`, `.ts.net` and single-label names are never sent to getaddrinfo.
        var fresh = ResolverRouting.State()
        #expect(ResolverRouting.claimHostsNeedingResolution(&fresh, ["http://10.0.0.5:7878", "http://nas.local", "https://box.tailnet.ts.net", "http://nas:7878"], now: t0).isEmpty)
    }
}
