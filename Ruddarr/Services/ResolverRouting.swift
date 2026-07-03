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
        /// `getaddrinfo` at most once per `resolveRetryInterval` — this doubles as the in-flight
        /// guard, so no separate "resolving" set is needed. Unlike the maps above it survives a
        /// fingerprint change (cleared only by `networkChanged`), so a flapping fingerprint can't
        /// wipe the throttle and storm lookups.
        var resolveAttemptedAt: [String: Date] = [:]
    }

    /// Ranks `candidates` for the current network and claims any hostnames that still need a
    /// background lookup. Clears the caches first if the network changed since the last call.
    static func register(
        _ state: inout State,
        candidates: [String],
        snapshot: NetworkSnapshot,
        fingerprint: String,
        now: Date
    ) -> (ordered: [String], pending: [String]) {
        syncFingerprint(&state, to: fingerprint)

        let demoted = activeDemotions(&state, now: now)
        let resolved = cachedRoles(state.resolvedHosts, for: candidates)
        let ordered = NetworkInterfaces.orderedBases(
            candidates, snapshot: snapshot, demoted: demoted, resolved: resolved
        )

        let pending = claimHostsNeedingResolution(&state, candidates, now: now)
        return (ordered, pending)
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
        let ordered = NetworkInterfaces.orderedBases(candidates, snapshot: snapshot, demoted: demoted, resolved: resolved)
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
        state.epoch += 1
    }

    /// Writes back a completed lookup, but only if the caches haven't been cleared since it was
    /// dispatched (`epoch` still matches) — otherwise the stale result is dropped.
    static func recordResolution(_ state: inout State, host: String, epoch: Int, resolved: ResolvedHost?, now: Date) {
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
            if let last = state.resolveAttemptedAt[host], now.timeIntervalSince(last) < resolveRetryInterval { continue }

            state.resolveAttemptedAt[host] = now
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

    /// Drops the network-specific caches (resolutions and demotions) when the fingerprint
    /// changes, so anything learned on one network never leaks into the next, and bumps `epoch`
    /// so in-flight lookups for the old network are discarded on completion. The DNS-retry
    /// throttle (`resolveAttemptedAt`) is deliberately kept: a flapping fingerprint (tailnet
    /// reconnecting) would otherwise re-storm `getaddrinfo` on every swing. Only a real
    /// `networkChanged()` clears the throttle, so a genuine transition still re-resolves at once.
    private static func syncFingerprint(_ state: inout State, to fingerprint: String) {
        guard state.fingerprint != fingerprint else { return }

        state.fingerprint = fingerprint
        state.demotedUntil.removeAll()
        state.resolvedHosts.removeAll()
        state.epoch += 1
    }
}
