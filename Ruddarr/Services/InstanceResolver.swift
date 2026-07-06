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
/// - Self-correcting: on a fast failure, `API.request` calls `failover(afterFailing:for:)`,
///   which demotes that base for the current network and returns the instance's next-best one.
///
/// The resolved URL is purely runtime state and is never persisted, so it can never reach
/// iCloud, the App Group, or another device.
final class InstanceResolver: Sendable {
    static let shared = InstanceResolver()

    /// The routing state, reachable only through `lock.withLock`, so the class is
    /// checked-`Sendable` with no `@unchecked`.
    private let lock = OSAllocatedUnfairLock(initialState: ResolverRouting.State())

    private let resolutionQueue = DispatchQueue(label: "io.ruddarr.url-resolution", qos: .utility, attributes: .concurrent)

    /// Returns the best base URL string for `instance` on the current network, and kicks off
    /// any pending hostname lookups in the background.
    func resolve(_ instance: Instance) -> String {
        select(instance.candidateURLs, fallback: instance.url)
    }

    /// Read-only from the caller's view: the base URL `resolve` would return right now. May
    /// still schedule a background DNS refresh so the displayed selection converges.
    func currentSelection(for instance: Instance) -> String {
        select(instance.candidateURLs, fallback: instance.url)
    }

    /// The network changed (Wi-Fi/VPN/cellular). Drop everything learned about the old one so
    /// the next selection re-resolves once — catches transitions the subnet fingerprint can't
    /// tell apart (two different LANs sharing the same private subnet).
    func networkChanged() {
        lock.withLock { ResolverRouting.networkChanged(&$0) }
    }

    private func select(_ candidates: [String], fallback: String) -> String {
        guard candidates.count > 1 else {
            return candidates.first ?? fallback
        }

        // Capture the snapshot INSIDE the lock so the fingerprint used to sync the caches is
        // consistent with lock-acquisition order — a thread preempted between capture and lock
        // can't enter with a stale fingerprint and evict resolutions freshly cached for the
        // current network. `getaddrinfo`-free interface read, microseconds, no blocking.
        let (ordered, pending, epoch, snapshot): ([String], [String], Int, NetworkSnapshot) = lock.withLock { state in
            let snapshot = NetworkSnapshot.capture()
            let result = ResolverRouting.register(
                &state, candidates: candidates, snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
            )

            return (result.ordered, result.pending, state.epoch, snapshot)
        }

        dispatchResolution(pending, snapshot: snapshot, epoch: epoch)

        return ordered.first ?? candidates.first ?? fallback
    }

    /// Demotes the base that served `failedURL` and returns `instance`'s next-best candidate
    /// (same request path re-attached), or `nil` when there is nothing left to try. Only this
    /// instance's own candidates are ever considered, so a failed request can never be re-issued
    /// against another instance's host.
    func failover(afterFailing failedURL: URL, for instance: Instance) -> URL? {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return nil }

        return lock.withLock {
            let snapshot = NetworkSnapshot.capture()

            return ResolverRouting.failover(
                &$0, afterFailing: failedURL.absoluteString, candidates: candidates,
                snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
            )
        }
    }

    /// Clears any demotion for the base that served this URL — any HTTP response proves the host
    /// is reachable again. The `demotedUntil.isEmpty` check keeps the common (nothing-demoted)
    /// case off the `matchingBase` path.
    func noteSuccess(for url: URL, instance: Instance) {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return }

        lock.withLock { state in
            guard !state.demotedUntil.isEmpty else { return }
            ResolverRouting.noteSuccess(&state, for: url.absoluteString, candidates: candidates)
        }
    }

    /// A structured snapshot of the current network and, for each instance, why every candidate
    /// URL ranks where it does — unmasked, for the diagnostics screen to mask on demand.
    /// Read-only: it reflects what selection currently sees (cached resolutions, active
    /// demotions) and triggers no lookups. Only the two Sendable caches are read under the
    /// lock; ranking and normalization run outside it so requests don't contend while a
    /// report builds.
    func report(for instances: [Instance]) -> NetworkReport {
        let snapshot = NetworkSnapshot.capture()

        let (demoted, resolvedHosts): (Set<String>, [String: ResolvedHost]) = lock.withLock { state in
            (ResolverRouting.activeDemotions(&state, now: Date()), state.resolvedHosts)
        }

        let entries = instances.map { instance -> NetworkReport.InstanceEntry in
            let candidates = instance.candidateURLs
            let resolved = ResolverRouting.cachedRoles(resolvedHosts, for: candidates)
            let ranked = NetworkInterfaces.ranking(candidates, snapshot: snapshot, demoted: demoted, resolved: resolved)
            let selected = ranked.first?.base ?? candidates.first ?? instance.url

            let rows = ranked.map { entry -> NetworkReport.Candidate in
                let resolution = NetworkInterfaces.host(of: entry.base).flatMap { resolved[$0] }

                return NetworkReport.Candidate(
                    url: entry.base,
                    role: entry.role,
                    onLink: entry.onLink,
                    score: entry.score,
                    resolved: resolution != nil,
                    addresses: resolution?.addresses ?? [],
                    demoted: entry.demoted,
                    primary: entry.base == candidates.first,
                    selected: entry.base == selected
                )
            }

            return NetworkReport.InstanceEntry(
                id: instance.id,
                label: instance.label,
                type: instance.type.rawValue,
                mode: instance.mode.value,
                contextKey: instance.contextKey,
                selected: selected,
                candidates: rows
            )
        }

        let facts = NetworkPathFacts.current

        return NetworkReport(
            tailnetUp: snapshot.tailnetUp,
            localNetworkDenied: snapshot.localNetworkDenied,
            connection: facts.connection,
            constrained: facts.constrained,
            expensive: facts.expensive,
            lanV4: snapshot.lanV4.map(\.cidr),
            lanV6: snapshot.lanV6.map(\.cidr),
            deviceV4: snapshot.lanV4,
            deviceV6: snapshot.lanV6,
            gatewaysV4: RouteTable.defaultGatewaysV4(),
            fingerprint: snapshot.fingerprint,
            instances: entries
        )
    }

    /// The masked, Sentry-shaped rendering of `report(for:)` — for attaching to a bug report.
    func diagnostics(for instances: [Instance]) -> [String: Any] {
        let report = report(for: instances)

        var context: [String: Any] = [
            "tailscale": report.tailnetUp ? "up" : "down",
            "local_network": report.localNetworkDenied ? "denied" : "allowed",
            "lan_v4": report.lanV4.isEmpty ? "none" : report.lanV4.map(maskedCIDR).joined(separator: ", "),
            "lan_v6": report.lanV6.isEmpty ? "none" : report.lanV6.map(maskedCIDR).joined(separator: ", "),
        ]

        for entry in report.instances {
            guard entry.candidates.count > 1 else {
                context[entry.contextKey] = ["selected": maskedURL(entry.selected), "candidates": "single URL"]
                continue
            }

            let lines = entry.candidates.map { candidate -> String in
                var line = "\(maskedURL(candidate.url)) — \(candidate.summary)"
                if !candidate.addresses.isEmpty {
                    line += " → \(candidate.addresses.map(maskedIP).joined(separator: ", "))"
                }
                return line
            }

            context[entry.contextKey] = [
                "selected": maskedURL(entry.selected),
                "candidates": lines,
            ]
        }

        return context
    }

    private func dispatchResolution(_ hosts: [String], snapshot: NetworkSnapshot, epoch: Int) {
        guard !hosts.isEmpty else { return }

        for host in hosts {
            resolutionQueue.async { [self] in
                let outcome = Self.lookup(host)
                let resolved = outcome.ok
                    ? NetworkInterfaces.classify(ipv4: outcome.ipv4, ipv6: outcome.ipv6, snapshot: snapshot)
                    : nil

                lock.withLock { state in
                    ResolverRouting.recordResolution(&state, host: host, epoch: epoch, resolved: resolved, now: Date())
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
