import Foundation

/// The pure routing / self-correction state machine behind `InstanceResolver`, with no
/// `Instance` dependency (candidates are plain base-URL strings) and every clock reading
/// injected as `now`. That is what lets this logic compile into the Tests target — which has
/// no `@testable import` — and be exercised deterministically.
///
/// Failover carries the instance's own candidate list on every call, so a failed request can
/// only ever be re-issued against a URL belonging to that same instance — there is no global
/// URL→instance registry to go stale or to let one instance's request reach another's host.
enum ResolverRouting {
    static let probeTimeout: TimeInterval = 2
    static let demotionTTL: TimeInterval = 600
    static let resolveRetryInterval: TimeInterval = 30

    /// Everything the resolver learns about the current network. `InstanceResolver` guards it
    /// behind a lock; here it is a plain value so the transitions are directly testable. Every
    /// cache below describes reachability on the network identified by `fingerprint`, and is
    /// dropped the moment that changes — so the maps are keyed by plain base/host, not by a
    /// composite that would only ever hold one generation anyway.
    struct State {
        /// The network these caches belong to. When it changes they are all cleared.
        var fingerprint = ""

        /// Bumped whenever the caches are cleared. A background lookup captures it at dispatch
        /// and writes back only if it still matches, so a resolution computed for a superseded
        /// network can't land in the current cache (two different LANs can share a fingerprint).
        var epoch = 0

        /// base URL → the moment its demotion (after a failed request) expires.
        var demotedUntil: [String: Date] = [:]

        /// host → how that hostname resolves on the current network.
        var resolvedHosts: [String: ResolvedHost] = [:]

        /// host → when a lookup was last attempted (stamped at claim), so a name is re-sent to
        /// `getaddrinfo` at most once per `resolveRetryInterval`. Unlike the maps above it
        /// survives a fingerprint change (cleared only by `networkChanged`), so a flapping
        /// fingerprint can't wipe the throttle and storm lookups.
        var resolveAttemptedAt: [String: Date] = [:]

        /// Hosts with a lookup currently in flight. Claims skip these, and unlike the attempt
        /// stamps the set survives even `networkChanged`, so a burst of path updates can never
        /// stack a second blocking `getaddrinfo` for the same host onto the resolution queue —
        /// completion always clears the entry, even when the result lands stale and is dropped.
        var resolveInFlight: Set<String> = []

        /// base URL → the `/ping` verdict for an off-link private candidate on this network. A
        /// reachable verdict promotes the base above remote (the router demonstrably routes into
        /// its VLAN); a failed one is retried at most once per `resolveRetryInterval`.
        var probeOutcomes: [String: ProbeOutcome] = [:]

        /// base URL → when a probe was last dispatched or completed — the retry throttle, with
        /// the same fingerprint-flap semantics as `resolveAttemptedAt`.
        var probeAttemptedAt: [String: Date] = [:]

        /// Bases with a `/ping` probe currently in flight — same semantics as `resolveInFlight`.
        var probeInFlight: Set<String> = []

        /// base URL → whether a *browser* can reach this candidate on this network. Kept apart
        /// from `probeOutcomes` on purpose: it answers "could Safari open this?", not "where
        /// should the app talk?", it covers every candidate rather than only off-link private
        /// ones, and it never feeds ranking — so a check made for the UI can never move the
        /// app's own routing.
        var webOutcomes: [String: ProbeOutcome] = [:]

        /// base URL → when a web check was last dispatched or completed — the retry throttle,
        /// with the same fingerprint-flap semantics as `probeAttemptedAt`.
        var webAttemptedAt: [String: Date] = [:]

        /// Bases with a web check currently in flight — same semantics as `probeInFlight`.
        var webInFlight: Set<String> = []
    }

    /// Ranks `candidates` for the current network from cached state alone — the same
    /// fingerprint sync and ordering as `register`, but it claims nothing and dispatches
    /// nothing, so a passive caller (an instance row displaying the selection) can read it
    /// without generating lookup or probe traffic.
    static func rank(
        _ state: inout State,
        candidates: [String],
        snapshot: NetworkSnapshot,
        fingerprint: String,
        now: Date
    ) -> [String] {
        syncFingerprint(&state, to: fingerprint)

        let demoted = activeDemotions(&state, now: now)
        let resolved = cachedRoles(state.resolvedHosts, for: candidates)

        return NetworkInterfaces.orderedBases(
            candidates, snapshot: snapshot, demoted: demoted, resolved: resolved, probed: state.probeOutcomes
        )
    }

    /// Ranks `candidates` for the current network and claims any hostnames that still need a
    /// background lookup, plus any off-link private bases that still need a `/ping` probe.
    /// Clears the caches first if the network changed since the last call.
    static func register(
        _ state: inout State,
        candidates: [String],
        snapshot: NetworkSnapshot,
        fingerprint: String,
        now: Date
    ) -> (ordered: [String], pending: [String], probes: [String]) {
        let ordered = rank(&state, candidates: candidates, snapshot: snapshot, fingerprint: fingerprint, now: now)

        let pending = claimHostsNeedingResolution(&state, candidates, now: now)
        let probes = claimProbesNeeded(
            &state, candidates, snapshot: snapshot, resolved: cachedRoles(state.resolvedHosts, for: candidates), now: now
        )

        return (ordered, pending, probes)
    }

    /// Demotes the candidate that served `absolute` and returns the next-best sibling (same
    /// request path re-attached), or `nil` when nothing else is reachable. Ranking is redone
    /// against the fresh snapshot with the new demotion applied, so failover follows the same
    /// ladder as proactive selection.
    static func failover( // swiftlint:disable:this function_parameter_count
        _ state: inout State,
        afterFailing absolute: String,
        candidates: [String],
        snapshot: NetworkSnapshot,
        fingerprint: String,
        now: Date
    ) -> URL? {
        syncFingerprint(&state, to: fingerprint)

        guard let base = matchingBase(candidates, for: absolute) else { return nil }

        state.demotedUntil[base] = now.addingTimeInterval(demotionTTL)

        let demoted = activeDemotions(&state, now: now)
        let resolved = cachedRoles(state.resolvedHosts, for: candidates)
        let ordered = NetworkInterfaces.orderedBases(
            candidates, snapshot: snapshot, demoted: demoted, resolved: resolved, probed: state.probeOutcomes
        )
        let suffix = String(absolute.dropFirst(base.count))

        for candidate in ordered where candidate != base && !demoted.contains(candidate) {
            if let url = URL(string: candidate + suffix) { return url }
        }

        return nil
    }

    /// Clears any demotion for the candidate that served `absolute` — a response proves it live.
    static func noteSuccess(_ state: inout State, for absolute: String, candidates: [String]) {
        guard let base = matchingBase(candidates, for: absolute) else { return }
        state.demotedUntil[base] = nil
    }

    /// Drops everything learned about the old network.
    static func networkChanged(_ state: inout State) {
        state.fingerprint = ""
        state.demotedUntil.removeAll()
        state.resolvedHosts.removeAll()
        state.resolveAttemptedAt.removeAll()
        state.probeOutcomes.removeAll()
        state.probeAttemptedAt.removeAll()
        state.webOutcomes.removeAll()
        state.webAttemptedAt.removeAll()
        state.epoch += 1
    }

    /// Writes back a completed lookup, but only if the caches haven't been cleared since it was
    /// dispatched (`epoch` still matches) — otherwise the stale result is dropped. The in-flight
    /// guard clears either way; the lookup is over.
    static func recordResolution(_ state: inout State, host: String, epoch: Int, resolved: ResolvedHost?, now: Date) {
        state.resolveInFlight.remove(host)

        guard state.epoch == epoch else { return }

        state.resolveAttemptedAt[host] = now

        if let resolved { state.resolvedHosts[host] = resolved }
    }

    /// The candidate that is the longest (most specific) base-URL prefix of `absolute`, honouring
    /// a `/`, `?` or end-of-string boundary so a sibling origin or a `-suffixed` path can't match.
    static func matchingBase(_ candidates: [String], for absolute: String) -> String? {
        candidates
            .filter { base in
                guard absolute.hasPrefix(base) else { return false }
                let boundary = absolute.dropFirst(base.count).first
                return boundary == nil || boundary == "/" || boundary == "?"
            }
            .max(by: { $0.count < $1.count })
    }

    static func activeDemotions(_ state: inout State, now: Date) -> Set<String> {
        state.demotedUntil = state.demotedUntil.filter { $0.value > now } // prune expired
        return Set(state.demotedUntil.keys)
    }

    static func cachedRoles(_ resolvedHosts: [String: ResolvedHost], for candidates: [String]) -> [String: ResolvedHost] {
        var map: [String: ResolvedHost] = [:]
        for base in candidates {
            guard let host = NetworkInterfaces.host(of: base) else { continue }
            if let resolution = resolvedHosts[host] { map[host] = resolution }
        }
        return map
    }

    /// Collects hostnames worth a fresh lookup — skipping literal IPs, `.local`, `.ts.net`,
    /// single-label names, already-cached, in-flight and recently-failed names — stamping each
    /// as attempted so a repeat within `resolveRetryInterval` (in flight or just failed) skips.
    static func claimHostsNeedingResolution(_ state: inout State, _ candidates: [String], now: Date) -> [String] {
        var hosts: [String] = []
        var seen: Set<String> = []

        for base in candidates {
            guard let host = NetworkInterfaces.host(of: base), shouldResolve(host) else { continue }
            guard seen.insert(host).inserted else { continue }

            if state.resolvedHosts[host] != nil { continue }
            if state.resolveInFlight.contains(host) { continue }
            if let last = state.resolveAttemptedAt[host], now.timeIntervalSince(last) < resolveRetryInterval { continue }

            state.resolveAttemptedAt[host] = now
            state.resolveInFlight.insert(host)
            hosts.append(host)
        }

        return hosts
    }

    /// `true` for plain hostnames worth resolving. Literal IPs already classify exactly;
    /// `.local` goes through Bonjour (which would trigger the Local Network prompt), `.ts.net`
    /// is handled by the tunnel-up signal, and a single-label name resolves via implicit mDNS —
    /// none should be sent to `getaddrinfo`.
    static func shouldResolve(_ host: String) -> Bool {
        let host = host.lowercased()
        if host.isEmpty { return false }
        if host.contains(":") { return false }             // IPv6 literal
        if NetworkInterfaces.isMDNSName(host) || NetworkInterfaces.isTailnetName(host) { return false }
        if NetworkInterfaces.isSingleLabel(host) { return false } // single-label name resolves via mDNS
        return NetworkInterfaces.parseIPv4(host) == nil     // IPv4 literal
    }

    // MARK: - Off-link probing

    /// Whether `base` is worth a background `/ping`: a private address — literal, or what its
    /// hostname resolved to — that is NOT on any of the device's own links. Such a server may
    /// sit on a sibling VLAN behind the same router, reachable only if the router routes into
    /// it, which is exactly what the probe finds out. Loopback is always on-link, link-local
    /// can never route (resolved names included), CGNAT / the Tailscale ULA belong to the
    /// tunnel, and mDNS / single-label names can't resolve off-link — none of those are probed.
    static func probeCandidate(_ base: String, resolved: [String: ResolvedHost], snapshot: NetworkSnapshot) -> Bool {
        guard let host = NetworkInterfaces.host(of: base) else { return false }

        if let resolution = resolved[host] {
            return resolution.role == .lan && !resolution.onLink && !resolution.isLoopback && !resolution.isLinkLocal
        }

        if let v4 = NetworkInterfaces.parseIPv4(host) {
            return NetworkInterfaces.isPrivateV4(v4)
                && !NetworkInterfaces.isLoopbackV4(v4)
                && !NetworkInterfaces.isLinkLocalV4(v4)
                && !snapshot.isOnLink(v4)
        }

        if let bytes = NetworkInterfaces.parseIPv6(host) {
            return NetworkInterfaces.isPrivateV6(bytes: bytes)
                && !NetworkInterfaces.isLoopbackV6(bytes: bytes)
                && !NetworkInterfaces.isLinkLocalV6(bytes: bytes)
                && !NetworkInterfaces.isTailscaleULA(bytes: bytes)
                && !snapshot.isOnLink(bytes)
        }

        return false
    }

    /// Collects off-link private bases worth a fresh `/ping` — skipping verified bases,
    /// in-flight probes and recent failures — stamping each as attempted, exactly like
    /// `claimHostsNeedingResolution` does for lookups. Probing needs a LAN: away from any
    /// local network there is no router that could route into the server's VLAN. And it
    /// needs a reason: while a sibling candidate is reachable on-link (score 100), a verified
    /// routed verdict (95) could never change selection, so nothing is claimed — without
    /// stamping the throttle, so the first claim after that sibling demotes fires at once.
    static func claimProbesNeeded(
        _ state: inout State,
        _ candidates: [String],
        snapshot: NetworkSnapshot,
        resolved: [String: ResolvedHost],
        now: Date
    ) -> [String] {
        guard snapshot.hasLAN else { return [] }

        let demoted = activeDemotions(&state, now: now)
        let ranked = NetworkInterfaces.ranking(
            candidates, snapshot: snapshot, demoted: demoted, resolved: resolved, probed: state.probeOutcomes
        )

        guard !ranked.contains(where: { !$0.demoted && $0.score == NetworkInterfaces.onLinkScore }) else { return [] }

        var bases: [String] = []

        for base in candidates {
            guard probeCandidate(base, resolved: resolved, snapshot: snapshot) else { continue }

            if state.probeOutcomes[base]?.reachable == true { continue }
            if state.probeInFlight.contains(base) { continue }
            if let last = state.probeAttemptedAt[base], now.timeIntervalSince(last) < resolveRetryInterval { continue }

            state.probeAttemptedAt[base] = now
            state.probeInFlight.insert(base)
            bases.append(base)
        }

        return bases
    }

    /// Writes back a completed probe, unless the caches were cleared since it was dispatched
    /// (`epoch` no longer matches). Failures are recorded too — the diagnostics screen shows
    /// them — and re-stamping the attempt schedules the next retry a full interval after
    /// *completion*, not dispatch. The in-flight guard clears either way; the probe is over.
    static func recordProbe(_ state: inout State, base: String, epoch: Int, outcome: ProbeOutcome, now: Date) {
        state.probeInFlight.remove(base)

        guard state.epoch == epoch else { return }

        state.probeAttemptedAt[base] = now
        state.probeOutcomes[base] = outcome
    }

    /// Collects candidates due a fresh browser-facing `/ping`. Unlike `claimProbesNeeded` this
    /// takes *every* candidate and needs no LAN: the question is whether a browser could open
    /// the URL from wherever the device is right now, which is as meaningful on cellular as it
    /// is at home. A verified base is re-checked on the same throttle as a failed one — the web
    /// button reflects reachability, so an instance that went down has to stop counting without
    /// waiting for a network change.
    static func claimWebChecksNeeded(_ state: inout State, _ candidates: [String], now: Date) -> [String] {
        var bases: [String] = []

        for base in candidates {
            if state.webInFlight.contains(base) { continue }
            if let last = state.webAttemptedAt[base], now.timeIntervalSince(last) < resolveRetryInterval { continue }

            state.webAttemptedAt[base] = now
            state.webInFlight.insert(base)
            bases.append(base)
        }

        return bases
    }

    /// Writes back a completed web check, dropping a result whose caches were cleared since it
    /// was dispatched (`epoch` no longer matches) — the same contract as `recordProbe`, and the
    /// same reason the in-flight guard clears either way.
    static func recordWebCheck(_ state: inout State, base: String, epoch: Int, outcome: ProbeOutcome, now: Date) {
        state.webInFlight.remove(base)

        guard state.epoch == epoch else { return }

        state.webAttemptedAt[base] = now
        state.webOutcomes[base] = outcome
    }

    /// The candidate the web button should open, from cached web verdicts alone: the best-ranked
    /// verified base, else the best-ranked one that answered at all — Safari may hold a session
    /// the unauthenticated check cannot see, so an answering host is never written off — else
    /// `nil`, which is what disables the button. `candidates` must already be in ranked order.
    static func webSelection(_ candidates: [String], outcomes: [String: ProbeOutcome]) -> String? {
        var answered: String?

        for base in candidates {
            guard let outcome = outcomes[base] else { continue }
            if outcome.reachable { return base }
            if answered == nil && outcome.answered { answered = base }
        }

        return answered
    }

    /// The unauthenticated `{base}/ping` endpoint (Radarr and Sonarr both serve it), with any
    /// inline credentials stripped — no secret ever rides along to an address that isn't
    /// verified yet.
    static func probeURL(for base: String) -> URL? {
        guard var components = URLComponents(string: base), components.host != nil else { return nil }

        components.user = nil
        components.password = nil
        components.path += "/ping"
        components.query = nil
        components.fragment = nil

        return components.url
    }

    /// Whether a probe response proves a live *arr instance at the probed address: HTTP success
    /// from the SAME host (a redirect elsewhere proves nothing about this address) with the
    /// exact `{"status": "OK"}` shape `/ping` returns. A captive portal, a stranger's web UI or
    /// a lookalike health endpoint fails this, so no promotion — and therefore no authenticated
    /// request — ever follows from an answer that isn't Radarr/Sonarr.
    static func probeVerdict(status: Int, finalHost: String?, probedHost: String?, body: Data) -> Bool {
        guard (200...299).contains(status) else { return false }

        guard let probedHost, let finalHost,
              NetworkInterfaces.bareHost(finalHost).lowercased() == NetworkInterfaces.bareHost(probedHost).lowercased()
        else { return false }

        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let value = object["status"] as? String
        else { return false }

        return value.caseInsensitiveCompare("OK") == .orderedSame
    }

    /// Drops the network-specific caches (resolutions, demotions and probe verdicts) when the
    /// fingerprint changes, so anything learned on one network never leaks into the next, and bumps `epoch`
    /// so in-flight lookups for the old network are discarded on completion. The DNS-retry
    /// throttle (`resolveAttemptedAt`) is deliberately kept: a flapping fingerprint (tailnet
    /// reconnecting) would otherwise re-storm `getaddrinfo` on every swing. Only a real
    /// `networkChanged()` clears the throttle, so a genuine transition still re-resolves at once.
    ///
    /// The web-check caches follow the probe rules for the same reason, one step more visible:
    /// a verdict earned at home must never vouch for a URL on cellular, and keeping its throttle
    /// would leave the web button disabled for up to `resolveRetryInterval` after every swing.
    ///
    /// The probe throttle is NOT kept: a wiped verdict must be re-earnable at once, or the
    /// verified candidate scores 30 instead of 95 for up to `resolveRetryInterval` and every
    /// instance row flips selection and re-checks against a slower fallback — a visible
    /// blackout on every fingerprint swing. Unlike `getaddrinfo`, a probe is bounded (2s
    /// timeout), single-flight per base, and gated off entirely while an on-link sibling wins.
    private static func syncFingerprint(_ state: inout State, to fingerprint: String) {
        guard state.fingerprint != fingerprint else { return }

        state.fingerprint = fingerprint
        state.demotedUntil.removeAll()
        state.resolvedHosts.removeAll()
        state.probeOutcomes.removeAll()
        state.probeAttemptedAt.removeAll()
        state.webOutcomes.removeAll()
        state.webAttemptedAt.removeAll()
        state.epoch += 1
    }
}
