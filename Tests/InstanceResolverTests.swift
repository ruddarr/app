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

    // MARK: - matchingBase boundaries (finding #1)

    @Test func matchingBaseRespectsPathAndPortBoundaries() {
        let routes = [
            "https://nas.example.com": ["https://nas.example.com"],
            "https://nas.example.com/radarr": ["https://nas.example.com/radarr"],
        ]
        // A real request path boundary matches, and the longest prefix wins.
        #expect(ResolverRouting.matchingBase(routes, for: "https://nas.example.com/api/v3/movie") == "https://nas.example.com")
        #expect(ResolverRouting.matchingBase(routes, for: "https://nas.example.com/radarr/api/v3/movie") == "https://nas.example.com/radarr")
        // A query-string boundary matches too.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com": []], for: "https://nas.example.com?x=1") == "https://nas.example.com")
        // A different port is a *sibling* origin, not this base.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com": []], for: "https://nas.example.com:8989/api/v3/series") == nil)
        // `/radarr-4k` must not be swallowed by the `/radarr` base.
        #expect(ResolverRouting.matchingBase(["https://nas.example.com/radarr": []], for: "https://nas.example.com/radarr-4k/api") == nil)
    }

    // MARK: - Self-correction loop

    @Test func selfCorrectsThroughFailoverAndRecovers() {
        var state = ResolverRouting.State()

        // Two remote candidates rank as a tie → canonical order, both routes recorded.
        let first = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, registerRoutes: true, now: t0)
        #expect(first.ordered == [a, b])

        // `a` fails on a request → demoted; the next-best sibling is returned with the path
        // re-attached (and on the boundary, not a fabricated port).
        let next = ResolverRouting.nextCandidate(&state, afterFailing: a + "/api/v3/movie", fingerprint: fingerprint, now: t0)
        #expect(next == URL(string: b + "/api/v3/movie"))

        // The next selection prefers `b` while `a` stays demoted.
        let second = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, registerRoutes: true, now: t0)
        #expect(second.ordered == [b, a])

        // `a` responds again → its demotion clears and canonical order returns.
        ResolverRouting.noteSuccess(&state, for: a + "/api/v3/movie", fingerprint: fingerprint)
        let third = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, registerRoutes: true, now: t0)
        #expect(third.ordered == [a, b])
    }

    @Test func nextCandidateReturnsNilWithoutARegisteredRoute() {
        var state = ResolverRouting.State()
        #expect(!ResolverRouting.hasRoute(state, for: a + "/api/v3/movie"))
        #expect(ResolverRouting.nextCandidate(&state, afterFailing: a + "/api/v3/movie", fingerprint: fingerprint, now: t0) == nil)
    }

    // MARK: - Route pruning (finding #7)

    @Test func pruneRoutesDropsGoneInstances() {
        var state = ResolverRouting.State()
        _ = ResolverRouting.register(&state, candidates: [a, b], snapshot: away, fingerprint: fingerprint, registerRoutes: true, now: t0)
        #expect(ResolverRouting.hasRoute(state, for: a + "/api"))
        #expect(ResolverRouting.hasRoute(state, for: b + "/api"))

        // The instance's remaining live URL is `b` → `a`'s stale route is pruned.
        ResolverRouting.pruneRoutes(&state, keeping: [b])
        #expect(!ResolverRouting.hasRoute(state, for: a + "/api"))
        #expect(ResolverRouting.hasRoute(state, for: b + "/api"))
    }

    // MARK: - Network change + epoch guard (finding #3)

    @Test func networkChangedClearsDemotionsAndBumpsEpoch() {
        var state = ResolverRouting.State()
        state.demotedUntil["\(fingerprint)\u{1}\(a)"] = t0.addingTimeInterval(600)
        let before = state.epoch

        ResolverRouting.networkChanged(&state)

        #expect(state.epoch == before + 1)
        #expect(state.demotedUntil.isEmpty)
    }

    @Test func recordResolutionDropsResultFromASupersededEpoch() {
        var state = ResolverRouting.State()
        state.epoch = 5
        let host = "radarr.example.com"
        let onLink = ResolvedHost(role: .lan, onLink: true)

        // A lookup dispatched before a network change (epoch 4) must not land now (epoch 5).
        ResolverRouting.recordResolution(&state, host: host, fingerprint: fingerprint, epoch: 4, resolved: onLink, now: t0)
        #expect(state.resolvedHosts.isEmpty)

        // The current epoch writes through.
        ResolverRouting.recordResolution(&state, host: host, fingerprint: fingerprint, epoch: 5, resolved: onLink, now: t0)
        #expect(state.resolvedHosts["\(fingerprint)\u{1}\(host)"] == onLink)
    }

    // MARK: - Demotion TTL + fingerprint scoping

    @Test func activeDemotionsExpireAndAreFingerprintScoped() {
        var state = ResolverRouting.State()
        state.demotedUntil["\(fingerprint)\u{1}\(a)"] = t0.addingTimeInterval(-1)   // already expired
        state.demotedUntil["\(fingerprint)\u{1}\(b)"] = t0.addingTimeInterval(100)  // still active
        state.demotedUntil["other-network\u{1}\(a)"] = t0.addingTimeInterval(100)   // a different network

        let demoted = ResolverRouting.activeDemotions(&state, for: fingerprint, now: t0)

        #expect(demoted == [b])                                        // only the active, in-scope one
        #expect(state.demotedUntil["\(fingerprint)\u{1}\(a)"] == nil)  // expired entry pruned from state
    }

    // MARK: - Lookup claiming

    @Test func claimHostsResolvesEachHostOnceAndSkipsNonResolvables() {
        var state = ResolverRouting.State()

        // A plain hostname is claimed once; the immediate retry sees it in flight and skips.
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, ["https://radarr.example.com"], fingerprint: fingerprint, now: t0) == ["radarr.example.com"])
        #expect(ResolverRouting.claimHostsNeedingResolution(&state, ["https://radarr.example.com"], fingerprint: fingerprint, now: t0).isEmpty)

        // IP literals, `.local` and `.ts.net` are never sent to getaddrinfo.
        var fresh = ResolverRouting.State()
        #expect(ResolverRouting.claimHostsNeedingResolution(&fresh, ["http://10.0.0.5:7878", "http://nas.local", "https://box.tailnet.ts.net"], fingerprint: fingerprint, now: t0).isEmpty)
    }
}
