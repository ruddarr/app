import os
import Foundation

/// Chooses which of an instance's URLs to use for the current network, and recovers
/// fast when that choice turns out to be wrong.
///
/// - Proactive: `resolve(_:)` reads a fresh `NetworkSnapshot` and returns the most
///   reachable base URL (on-link LAN at home, Tailscale when the tunnel is up, else
///   remote) — no request sent, nothing waits on a timeout.
/// - Resolution-aware: a candidate addressed by *hostname* (not a literal IP) is looked
///   up with `getaddrinfo` on a background queue and classified by where its A/AAAA
///   records actually point. This lets a split-horizon name —
///   `radarr.examplehomelab.com` whose record is a private IP at home — be picked as
///   on-link LAN while the public/tunnel name stays remote, with no probing or timeouts.
/// - Once per network: a lookup runs at most once per network condition, cached by the
///   fingerprint until `NWPathMonitor` calls `networkChanged()` on a Wi-Fi/VPN/cellular
///   transition to drop the cache. The lexical role is used until the first lookup lands,
///   so the happy path never blocks on DNS.
/// - Self-correcting: on a fast failure/timeout, `API.request` calls
///   `nextCandidate(afterFailing:)`, which demotes that base for the current network and
///   returns the next-best one. The demotion is fingerprint-scoped, so it is paid at most
///   once per network and forgotten when the network changes.
///
/// The resolved URL is purely runtime state and is never persisted, so it can never
/// reach iCloud, the App Group, or another device.
final class InstanceResolver: Sendable {
    static let shared = InstanceResolver()

    /// Everything the resolver learns about the current network, guarded as one unit by
    /// `lock`. Bundling the mutable state behind an `OSAllocatedUnfairLock` (same idiom as
    /// `Dependencies`) lets the class be checked-`Sendable` with no `@unchecked`: the state
    /// is unreachable except through `lock.withLock`.
    private struct State {
        /// base URL → the ordered candidate bases for its instance on the last resolve.
        var routes: [String: [String]] = [:]

        /// "fingerprint\u{1}base" → the moment its demotion expires.
        var demotedUntil: [String: Date] = [:]

        /// "fingerprint\u{1}host" → how that hostname resolves on the current network.
        var resolvedHosts: [String: ResolvedHost] = [:]

        /// "fingerprint\u{1}host" → when a lookup was last attempted, so a name that fails
        /// to resolve (e.g. an internal-only name while away) is retried at most once per
        /// `resolveRetryInterval`.
        var resolveAttemptedAt: [String: Date] = [:]

        /// "fingerprint\u{1}host" keys with a lookup in flight (de-dupes concurrent work).
        var resolving: Set<String> = []

        /// Bumped on every `networkChanged()`. A background lookup captures it at dispatch
        /// and writes its result back only if it still matches, so a resolution computed for
        /// the old network can't land in the new one's cache — the two can share a
        /// fingerprint when different LANs use the same private subnet.
        var epoch = 0
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    private static let demotionTTL: TimeInterval = 600
    private static let resolveRetryInterval: TimeInterval = 30

    private let resolutionQueue = DispatchQueue(label: "io.ruddarr.url-resolution", qos: .utility)

    /// Returns the best base URL string for `instance` on the current network, and kicks
    /// off any pending hostname lookups in the background.
    func resolve(_ instance: Instance) -> String {
        select(instance, registerRoutes: true)
    }

    /// Read-only: the base URL `resolve` would return right now. Registers no routes,
    /// but may schedule a background DNS refresh so the displayed selection converges.
    func currentSelection(for instance: Instance) -> String {
        select(instance, registerRoutes: false)
    }

    /// The network changed (Wi-Fi/VPN/cellular). Drop everything learned about the old
    /// one — resolutions, demotions, throttles — so the next selection re-resolves once.
    /// Catches transitions the subnet fingerprint can't tell apart (two different LANs
    /// sharing the same private subnet).
    func networkChanged() {
        lock.withLock { state in
            state.resolvedHosts.removeAll()
            state.resolveAttemptedAt.removeAll()
            state.resolving.removeAll()
            state.demotedUntil.removeAll()
            state.epoch += 1
        }
    }

    private func select(_ instance: Instance, registerRoutes: Bool) -> String {
        let candidates = instance.candidateURLs

        guard candidates.count > 1 else {
            return candidates.first ?? instance.url
        }

        let snapshot = NetworkSnapshot.capture()
        let fingerprint = snapshot.fingerprint

        let (chosen, pending, epoch): (String, [String], Int) = lock.withLock { state in
            Self.pruneResolution(in: &state, keeping: fingerprint)

            let demoted = Self.activeDemotions(in: &state, for: fingerprint)
            let resolved = Self.cachedRoles(state.resolvedHosts, for: candidates, fingerprint: fingerprint)
            let ordered = NetworkInterfaces.orderedBases(
                candidates, snapshot: snapshot, demoted: demoted, resolved: resolved
            )

            if registerRoutes {
                for base in candidates { state.routes[base] = ordered }
            }

            let pending = Self.claimHostsNeedingResolution(in: &state, candidates, fingerprint: fingerprint)

            return (ordered.first ?? candidates.first ?? instance.url, pending, state.epoch)
        }

        dispatchResolution(pending, snapshot: snapshot, fingerprint: fingerprint, epoch: epoch)

        return chosen
    }

    /// Maps a failed request URL back to its next-best sibling base, demoting the one
    /// that just failed. Returns `nil` when there is nothing left to try.
    func nextCandidate(afterFailing failedURL: URL) -> URL? {
        let absolute = failedURL.absoluteString

        guard (lock.withLock { Self.matchingBase($0.routes, for: absolute) }) != nil else { return nil }

        let fingerprint = NetworkSnapshot.capture().fingerprint
        let expiry = Date().addingTimeInterval(Self.demotionTTL)

        return lock.withLock { state -> URL? in
            guard let base = Self.matchingBase(state.routes, for: absolute) else { return nil }

            state.demotedUntil["\(fingerprint)\u{1}\(base)"] = expiry

            guard let ordered = state.routes[base] else { return nil }
            let demoted = Self.activeDemotions(in: &state, for: fingerprint)

            let suffix = String(absolute.dropFirst(base.count))

            for candidate in ordered where candidate != base && !demoted.contains(candidate) {
                if let url = URL(string: candidate + suffix) {
                    return url
                }
            }

            return nil
        }
    }

    /// Clears any demotion for the base that served this URL — any HTTP response proves
    /// the host is reachable again.
    func noteSuccess(for url: URL) {
        let absolute = url.absoluteString

        guard let base = (lock.withLock { Self.matchingBase($0.routes, for: absolute) }) else { return }

        let fingerprint = NetworkSnapshot.capture().fingerprint
        lock.withLock { state in
            state.demotedUntil["\(fingerprint)\u{1}\(base)"] = nil
        }
    }

    /// Drops route entries whose base no longer belongs to any current instance — call when
    /// instances are edited or removed so a stale base can't keep matching failed requests.
    func pruneRoutes(keeping instances: [Instance]) {
        let live = Set(instances.flatMap { $0.candidateURLs })
        lock.withLock { state in
            state.routes = state.routes.filter { live.contains($0.key) }
        }
    }

    // MARK: - Diagnostics

    /// A human-readable snapshot of the current network and, for each instance, why every
    /// candidate URL ranks where it does — for attaching to a bug report. Read-only: it
    /// reflects what selection currently sees (cached resolutions, active demotions) and
    /// triggers no lookups.
    func diagnostics(for instances: [Instance]) -> [String: Any] {
        let snapshot = NetworkSnapshot.capture()
        let fingerprint = snapshot.fingerprint

        // Rank every instance under the lock, then format the `[String: Any]` report
        // outside it — `Any` isn't `Sendable`, so it must not cross the `withLock` body.
        let rows: [DiagnosticRow] = lock.withLock { state in
            let demoted = Self.activeDemotions(in: &state, for: fingerprint)
            let resolvedHosts = state.resolvedHosts

            return instances.map { instance in
                let candidates = instance.candidateURLs
                let key = "\(instance.type.rawValue.lowercased())-\(instance.id.shortened)"

                guard candidates.count > 1 else {
                    return DiagnosticRow(key: key, selected: candidates.first ?? instance.url, lines: nil)
                }

                let resolved = Self.cachedRoles(resolvedHosts, for: candidates, fingerprint: fingerprint)
                let ranked = NetworkInterfaces.ranking(
                    candidates, snapshot: snapshot, demoted: demoted, resolved: resolved
                )

                let lines = ranked.map { entry -> String in
                    let wasResolved = NetworkInterfaces.host(of: entry.base).map { resolved[$0] != nil } ?? false
                    return "\(entry.base) — \(Self.label(entry, resolved: wasResolved))"
                }

                return DiagnosticRow(
                    key: key,
                    selected: ranked.first?.base ?? candidates.first ?? instance.url,
                    lines: lines
                )
            }
        }

        var context: [String: Any] = [
            "tailscale": snapshot.tailnetUp ? "up" : "down",
            "lan_v4": snapshot.lanV4.isEmpty ? "none" : snapshot.lanV4.map(\.cidr).joined(separator: ", "),
            "lan_v6": snapshot.lanV6.isEmpty ? "none" : snapshot.lanV6.map(\.cidr).joined(separator: ", "),
        ]

        for row in rows {
            if let lines = row.lines {
                context[row.key] = ["selected": row.selected, "candidates": lines]
            } else {
                context[row.key] = ["selected": row.selected, "candidates": "single URL"]
            }
        }

        return context
    }

    /// One instance's ranked breakdown, lifted out from under the lock so the report can
    /// be assembled without holding it. `lines == nil` marks a single-URL instance.
    private struct DiagnosticRow: Sendable {
        let key: String
        let selected: String
        let lines: [String]?
    }

    private static func label(_ entry: NetworkInterfaces.CandidateRanking, resolved: Bool) -> String {
        let role: String
        switch entry.role {
        case .lan: role = entry.onLink ? "on-link LAN" : "off-link LAN"
        case .tailscale: role = "Tailscale"
        case .remote: role = "remote"
        }

        var parts = [role, "score \(entry.score)", resolved ? "resolved" : "lexical"]
        if entry.demoted { parts.append("demoted") }

        return parts.joined(separator: ", ")
    }

    // MARK: - State helpers (call inside `lock.withLock`)

    private static func matchingBase(_ routes: [String: [String]], for absolute: String) -> String? {
        routes.keys
            .filter { base in
                guard absolute.hasPrefix(base) else { return false }
                let boundary = absolute.dropFirst(base.count).first
                return boundary == nil || boundary == "/" || boundary == "?"
            }
            .max(by: { $0.count < $1.count }) // longest (most specific) prefix wins
    }

    private static func activeDemotions(in state: inout State, for fingerprint: String) -> Set<String> {
        let now = Date()
        state.demotedUntil = state.demotedUntil.filter { $0.value > now } // prune expired

        let prefix = "\(fingerprint)\u{1}"
        return Set(
            state.demotedUntil.keys
                .filter { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
        )
    }

    private static func cachedRoles(
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

    /// Collects the hostnames worth a fresh lookup — skipping literal IPs, `.local` and
    /// `.ts.net`, already-cached, in-flight, and recently-failed names — and marks each
    /// in flight. The caller dispatches the actual lookups outside the lock.
    private static func claimHostsNeedingResolution(
        in state: inout State,
        _ candidates: [String],
        fingerprint: String
    ) -> [String] {
        let now = Date()
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

    private static func pruneResolution(in state: inout State, keeping fingerprint: String) {
        let prefix = "\(fingerprint)\u{1}"
        state.resolvedHosts = state.resolvedHosts.filter { $0.key.hasPrefix(prefix) }
        state.resolveAttemptedAt = state.resolveAttemptedAt.filter { $0.key.hasPrefix(prefix) }
    }

    // MARK: - DNS resolution (off the lock, on `resolutionQueue`)

    private func dispatchResolution(_ hosts: [String], snapshot: NetworkSnapshot, fingerprint: String, epoch: Int) {
        guard !hosts.isEmpty else { return }

        for host in hosts {
            resolutionQueue.async { [self] in
                let outcome = Self.lookup(host)
                let key = "\(fingerprint)\u{1}\(host)"

                lock.withLock { state in
                    guard state.epoch == epoch else { return } // network changed since dispatch; drop stale result

                    state.resolving.remove(key)
                    state.resolveAttemptedAt[key] = Date()

                    if outcome.ok {
                        state.resolvedHosts[key] = NetworkInterfaces.classify(
                            ipv4: outcome.ipv4, ipv6: outcome.ipv6, snapshot: snapshot
                        )
                    }
                }
            }
        }
    }

    /// `true` for plain hostnames worth resolving. Literal IPs already classify exactly;
    /// `.local` goes through Bonjour (which *would* trigger the Local Network prompt) and
    /// `.ts.net` is handled by the tunnel-up signal — none should be sent to `getaddrinfo`.
    private static func shouldResolve(_ host: String) -> Bool {
        let host = host.lowercased()
        if host.isEmpty { return false }
        if host.contains(":") { return false }             // IPv6 literal
        if host.hasSuffix(".local") || host.hasSuffix(".ts.net") { return false }
        return NetworkInterfaces.parseIPv4(host) == nil     // IPv4 literal
    }

    private static func lookup(_ host: String) -> (ipv4: [UInt32], ipv6: [in6_addr], ok: Bool) {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0, let first = info else {
            return ([], [], false)
        }
        defer { freeaddrinfo(info) }

        var ipv4: [UInt32] = []
        var ipv6: [in6_addr] = []

        for pointer in sequence(first: first, next: { $0.pointee.ai_next }) {
            guard let address = pointer.pointee.ai_addr else { continue }

            switch pointer.pointee.ai_family {
            case AF_INET:
                let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
                }
                ipv4.append(value)
            case AF_INET6:
                let value = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    $0.pointee.sin6_addr
                }
                ipv6.append(value)
            default:
                break
            }
        }

        return (ipv4, ipv6, true)
    }
}
