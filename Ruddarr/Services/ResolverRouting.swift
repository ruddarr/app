import Foundation

/// The pure routing / self-correction state machine behind `InstanceResolver`, with no
/// `Instance` dependency (candidates are plain base-URL strings) and every clock reading
/// injected as `now`. That is what lets this logic compile into the Tests target — which has
/// no `@testable import` — and be exercised deterministically.
enum ResolverRouting {
    static let demotionTTL: TimeInterval = 600
    static let resolveRetryInterval: TimeInterval = 30

    /// Everything the resolver learns about the current network. `InstanceResolver` guards it
    /// behind a lock; here it is a plain value so the transitions are directly testable.
    struct State {
        /// base URL → the ordered candidate bases for its instance on the last resolve.
        var routes: [String: [String]] = [:]

        /// "fingerprint\u{1}base" → the moment its demotion expires.
        var demotedUntil: [String: Date] = [:]

        /// "fingerprint\u{1}host" → how that hostname resolves on the current network.
        var resolvedHosts: [String: ResolvedHost] = [:]

        /// "fingerprint\u{1}host" → when a lookup was last attempted, so a name that fails to
        /// resolve is retried at most once per `resolveRetryInterval`.
        var resolveAttemptedAt: [String: Date] = [:]

        /// "fingerprint\u{1}host" keys with a lookup in flight (de-dupes concurrent work).
        var resolving: Set<String> = []

        /// Bumped on every `networkChanged()`. A background lookup captures it at dispatch and
        /// writes back only if it still matches, so a resolution computed for the old network
        /// can't land in the new one's cache — the two can share a fingerprint when different
        /// LANs use the same private subnet.
        var epoch = 0
    }

    /// Ranks `candidates` for the current network, optionally records the routes for later
    /// failover, and claims any hostnames that still need a background lookup.
    static func register( // swiftlint:disable:this function_parameter_count
        _ state: inout State,
        candidates: [String],
        snapshot: NetworkSnapshot,
        fingerprint: String,
        registerRoutes: Bool,
        now: Date
    ) -> (ordered: [String], pending: [String]) {
        pruneResolution(&state, keeping: fingerprint)

        let demoted = activeDemotions(&state, for: fingerprint, now: now)
        let resolved = cachedRoles(state.resolvedHosts, for: candidates, fingerprint: fingerprint)
        let ordered = NetworkInterfaces.orderedBases(
            candidates, snapshot: snapshot, demoted: demoted, resolved: resolved
        )

        if registerRoutes {
            for base in candidates { state.routes[base] = ordered }
        }

        let pending = claimHostsNeedingResolution(&state, candidates, fingerprint: fingerprint, now: now)
        return (ordered, pending)
    }

    static func hasRoute(_ state: State, for absolute: String) -> Bool {
        matchingBase(state.routes, for: absolute) != nil
    }

    /// Demotes the base that served `absolute` for the current network and returns the
    /// next-best sibling (same request path re-attached), or `nil` when nothing is left.
    static func nextCandidate(_ state: inout State, afterFailing absolute: String, fingerprint: String, now: Date) -> URL? {
        guard let base = matchingBase(state.routes, for: absolute) else { return nil }

        state.demotedUntil["\(fingerprint)\u{1}\(base)"] = now.addingTimeInterval(demotionTTL)

        guard let ordered = state.routes[base] else { return nil }
        let demoted = activeDemotions(&state, for: fingerprint, now: now)
        let suffix = String(absolute.dropFirst(base.count))

        for candidate in ordered where candidate != base && !demoted.contains(candidate) {
            if let url = URL(string: candidate + suffix) { return url }
        }

        return nil
    }

    /// Clears any demotion for the base that served `absolute` — a response proves it live.
    static func noteSuccess(_ state: inout State, for absolute: String, fingerprint: String) {
        guard let base = matchingBase(state.routes, for: absolute) else { return }
        state.demotedUntil["\(fingerprint)\u{1}\(base)"] = nil
    }

    /// Drops route entries whose base is not in `liveBases` (instance edited or removed).
    static func pruneRoutes(_ state: inout State, keeping liveBases: Set<String>) {
        state.routes = state.routes.filter { liveBases.contains($0.key) }
    }

    /// Drops everything learned about the old network and invalidates in-flight lookups.
    static func networkChanged(_ state: inout State) {
        state.resolvedHosts.removeAll()
        state.resolveAttemptedAt.removeAll()
        state.resolving.removeAll()
        state.demotedUntil.removeAll()
        state.epoch += 1
    }

    /// Writes back a completed lookup, but only if the network hasn't changed since it was
    /// dispatched (`epoch` still matches) — otherwise the stale result is dropped.
    static func recordResolution( // swiftlint:disable:this function_parameter_count
        _ state: inout State,
        host: String,
        fingerprint: String,
        epoch: Int,
        resolved: ResolvedHost?,
        now: Date
    ) {
        guard state.epoch == epoch else { return }

        let key = "\(fingerprint)\u{1}\(host)"
        state.resolving.remove(key)
        state.resolveAttemptedAt[key] = now

        if let resolved { state.resolvedHosts[key] = resolved }
    }

    static func matchingBase(_ routes: [String: [String]], for absolute: String) -> String? {
        routes.keys
            .filter { base in
                guard absolute.hasPrefix(base) else { return false }
                let boundary = absolute.dropFirst(base.count).first
                return boundary == nil || boundary == "/" || boundary == "?"
            }
            .max(by: { $0.count < $1.count }) // longest (most specific) prefix wins
    }

    static func activeDemotions(_ state: inout State, for fingerprint: String, now: Date) -> Set<String> {
        state.demotedUntil = state.demotedUntil.filter { $0.value > now } // prune expired

        let prefix = "\(fingerprint)\u{1}"
        return Set(
            state.demotedUntil.keys
                .filter { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
        )
    }

    static func cachedRoles(
        _ resolvedHosts: [String: ResolvedHost],
        for candidates: [String],
        fingerprint: String
    ) -> [String: ResolvedHost] {
        var map: [String: ResolvedHost] = [:]
        for base in candidates {
            guard let host = NetworkInterfaces.host(of: base) else { continue }
            if let resolution = resolvedHosts["\(fingerprint)\u{1}\(host)"] {
                map[host] = resolution
            }
        }
        return map
    }

    /// Collects hostnames worth a fresh lookup — skipping literal IPs, `.local`, `.ts.net`,
    /// already-cached, in-flight and recently-failed names — and marks each in flight.
    static func claimHostsNeedingResolution(
        _ state: inout State,
        _ candidates: [String],
        fingerprint: String,
        now: Date
    ) -> [String] {
        var hosts: [String] = []
        var seen: Set<String> = []

        for base in candidates {
            guard let host = NetworkInterfaces.host(of: base), shouldResolve(host) else { continue }
            guard seen.insert(host).inserted else { continue }

            let key = "\(fingerprint)\u{1}\(host)"
            if state.resolvedHosts[key] != nil { continue }
            if state.resolving.contains(key) { continue }
            if let last = state.resolveAttemptedAt[key], now.timeIntervalSince(last) < resolveRetryInterval { continue }

            state.resolving.insert(key)
            hosts.append(host)
        }

        return hosts
    }

    static func pruneResolution(_ state: inout State, keeping fingerprint: String) {
        let prefix = "\(fingerprint)\u{1}"
        state.resolvedHosts = state.resolvedHosts.filter { $0.key.hasPrefix(prefix) }
        state.resolveAttemptedAt = state.resolveAttemptedAt.filter { $0.key.hasPrefix(prefix) }
    }

    /// `true` for plain hostnames worth resolving. Literal IPs already classify exactly;
    /// `.local` goes through Bonjour (which would trigger the Local Network prompt) and
    /// `.ts.net` is handled by the tunnel-up signal — none should be sent to `getaddrinfo`.
    static func shouldResolve(_ host: String) -> Bool {
        let host = host.lowercased()
        if host.isEmpty { return false }
        if host.contains(":") { return false }             // IPv6 literal
        if host.hasSuffix(".local") || host.hasSuffix(".ts.net") { return false }
        return NetworkInterfaces.parseIPv4(host) == nil     // IPv4 literal
    }
}
