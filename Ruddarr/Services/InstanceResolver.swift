import os
import Foundation

/// Chooses which of an instance's URLs to use for the current network, and recovers fast
/// when that choice turns out to be wrong. The routing / self-correction state machine lives
/// in `ResolverRouting` (pure, unit-tested); this type owns the lock, reads the live
/// `NetworkSnapshot`, runs the background DNS lookups, and bridges `Instance` to plain
/// candidate URLs.
///
/// - Proactive: `resolve(_:)` reads a fresh `NetworkSnapshot` and returns the most reachable
///   base URL (on-link LAN at home, Tailscale when the tunnel is up, else remote) — no
///   request sent, nothing waits on a timeout.
/// - Resolution-aware: a candidate addressed by *hostname* is looked up with `getaddrinfo` on
///   a background queue and classified by where its A/AAAA records actually point, so a
///   split-horizon name is picked as on-link LAN while the public/tunnel name stays remote.
/// - Once per network: a lookup runs at most once per network condition, cached by the
///   fingerprint until `networkChanged()` drops the cache on a Wi-Fi/VPN/cellular transition.
/// - Self-correcting: on a fast failure, `API.request` calls `nextCandidate(afterFailing:)`,
///   which demotes that base for the current network and returns the next-best one.
///
/// The resolved URL is purely runtime state and is never persisted, so it can never reach
/// iCloud, the App Group, or another device.
final class InstanceResolver: Sendable {
    static let shared = InstanceResolver()

    /// The routing state, reachable only through `lock.withLock`, so the class is
    /// checked-`Sendable` with no `@unchecked`.
    private let lock = OSAllocatedUnfairLock(initialState: ResolverRouting.State())

    private let resolutionQueue = DispatchQueue(label: "io.ruddarr.url-resolution", qos: .utility)

    /// Returns the best base URL string for `instance` on the current network, and kicks off
    /// any pending hostname lookups in the background.
    func resolve(_ instance: Instance) -> String {
        select(instance.candidateURLs, fallback: instance.url, registerRoutes: true)
    }

    /// Read-only: the base URL `resolve` would return right now. Registers no routes, but may
    /// schedule a background DNS refresh so the displayed selection converges.
    func currentSelection(for instance: Instance) -> String {
        select(instance.candidateURLs, fallback: instance.url, registerRoutes: false)
    }

    /// The network changed (Wi-Fi/VPN/cellular). Drop everything learned about the old one so
    /// the next selection re-resolves once — catches transitions the subnet fingerprint can't
    /// tell apart (two different LANs sharing the same private subnet).
    func networkChanged() {
        lock.withLock { ResolverRouting.networkChanged(&$0) }
    }

    private func select(_ candidates: [String], fallback: String, registerRoutes: Bool) -> String {
        guard candidates.count > 1 else {
            return candidates.first ?? fallback
        }

        let snapshot = NetworkSnapshot.capture()
        let fingerprint = snapshot.fingerprint

        let (ordered, pending, epoch): ([String], [String], Int) = lock.withLock { state in
            let result = ResolverRouting.register(
                &state, candidates: candidates, snapshot: snapshot,
                fingerprint: fingerprint, registerRoutes: registerRoutes, now: Date()
            )
            return (result.ordered, result.pending, state.epoch)
        }

        dispatchResolution(pending, snapshot: snapshot, fingerprint: fingerprint, epoch: epoch)

        return ordered.first ?? candidates.first ?? fallback
    }

    /// Maps a failed request URL back to its next-best sibling base, demoting the one that
    /// just failed. Returns `nil` when there is nothing left to try. The cheap routes check
    /// runs first so the common no-route case skips the `getifaddrs` walk.
    func nextCandidate(afterFailing failedURL: URL) -> URL? {
        let absolute = failedURL.absoluteString

        guard (lock.withLock { ResolverRouting.hasRoute($0, for: absolute) }) else { return nil }

        let fingerprint = NetworkSnapshot.capture().fingerprint
        return lock.withLock { ResolverRouting.nextCandidate(&$0, afterFailing: absolute, fingerprint: fingerprint, now: Date()) }
    }

    /// Clears any demotion for the base that served this URL — any HTTP response proves the
    /// host is reachable again.
    func noteSuccess(for url: URL) {
        let absolute = url.absoluteString

        guard (lock.withLock { ResolverRouting.hasRoute($0, for: absolute) }) else { return }

        let fingerprint = NetworkSnapshot.capture().fingerprint
        lock.withLock { ResolverRouting.noteSuccess(&$0, for: absolute, fingerprint: fingerprint) }
    }

    /// Drops route entries whose base no longer belongs to any current instance — call when
    /// instances are edited or removed so a stale base can't keep matching failed requests.
    func pruneRoutes(keeping instances: [Instance]) {
        let live = Set(instances.flatMap { $0.candidateURLs })
        lock.withLock { ResolverRouting.pruneRoutes(&$0, keeping: live) }
    }

    // MARK: - Diagnostics

    /// A human-readable snapshot of the current network and, for each instance, why every
    /// candidate URL ranks where it does — for attaching to a bug report. Read-only: it
    /// reflects what selection currently sees (cached resolutions, active demotions) and
    /// triggers no lookups.
    func diagnostics(for instances: [Instance]) -> [String: Any] {
        let snapshot = NetworkSnapshot.capture()
        let fingerprint = snapshot.fingerprint

        // Rank every instance under the lock, then format the `[String: Any]` report outside
        // it — `Any` isn't `Sendable`, so it must not cross the `withLock` body.
        let rows: [DiagnosticRow] = lock.withLock { state in
            let demoted = ResolverRouting.activeDemotions(&state, for: fingerprint, now: Date())
            let resolvedHosts = state.resolvedHosts

            return instances.map { instance in
                let candidates = instance.candidateURLs
                let key = "\(instance.type.rawValue.lowercased())-\(instance.id.shortened)"

                guard candidates.count > 1 else {
                    return DiagnosticRow(key: key, selected: maskedURL(candidates.first ?? instance.url), lines: nil)
                }

                let resolved = ResolverRouting.cachedRoles(resolvedHosts, for: candidates, fingerprint: fingerprint)
                let ranked = NetworkInterfaces.ranking(
                    candidates, snapshot: snapshot, demoted: demoted, resolved: resolved
                )

                let lines = ranked.map { entry -> String in
                    let wasResolved = NetworkInterfaces.host(of: entry.base).map { resolved[$0] != nil } ?? false
                    return "\(maskedURL(entry.base)) — \(Self.label(entry, resolved: wasResolved))"
                }

                return DiagnosticRow(
                    key: key,
                    selected: maskedURL(ranked.first?.base ?? candidates.first ?? instance.url),
                    lines: lines
                )
            }
        }

        var context: [String: Any] = [
            "tailscale": snapshot.tailnetUp ? "up" : "down",
            "local_network": snapshot.localNetworkDenied ? "denied" : "allowed",
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

    /// One instance's ranked breakdown, lifted out from under the lock so the report can be
    /// assembled without holding it. `lines == nil` marks a single-URL instance.
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

    // MARK: - DNS resolution (off the lock, on `resolutionQueue`)

    private func dispatchResolution(_ hosts: [String], snapshot: NetworkSnapshot, fingerprint: String, epoch: Int) {
        guard !hosts.isEmpty else { return }

        for host in hosts {
            resolutionQueue.async { [self] in
                let outcome = Self.lookup(host)
                let resolved = outcome.ok
                    ? NetworkInterfaces.classify(ipv4: outcome.ipv4, ipv6: outcome.ipv6, snapshot: snapshot)
                    : nil

                lock.withLock { state in
                    ResolverRouting.recordResolution(
                        &state, host: host, fingerprint: fingerprint, epoch: epoch, resolved: resolved, now: Date()
                    )
                }
            }
        }
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
