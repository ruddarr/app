import Foundation

/// Chooses which of an instance's URLs to use for the current network, and recovers fast
/// when that choice turns out to be wrong. The routing / self-correction state machine lives
/// in `ResolverRouting` (pure, unit-tested); this actor owns the state — every transition is
/// serialized by actor isolation, no locks — reads the live `NetworkSnapshot`, and runs the
/// background DNS lookups and `/ping` probes.
///
/// - Proactive: `resolve(_:)` reads a fresh `NetworkSnapshot` and returns the most reachable
///   base URL (on-link LAN at home, Tailscale when the tunnel is up, else remote) — no
///   request sent, nothing waits on a timeout. It is the *converging* call: it also claims
///   any pending hostname lookups and `/ping` probes. `currentSelection(for:)` is the
///   *passive* read for UI — same ranking, but it never generates network traffic.
/// - Resolution-aware: a candidate addressed by *hostname* is looked up with `getaddrinfo` on
///   a dedicated background queue (a blocking syscall must never run on an actor or the
///   cooperative pool) and classified by where its A/AAAA records actually point, so a
///   split-horizon name is picked as on-link LAN while the public/tunnel name stays remote.
/// - Probe-verified: an off-link private candidate (a server on a sibling VLAN behind the same
///   router) gets a background, unauthenticated `GET /ping`; a genuine Radarr/Sonarr answer
///   from that address promotes it above remote. The probe carries no credentials, selection
///   never waits on it — the verdict lands in the cache and the next `resolve` picks it up.
/// - Once per network: a lookup or probe runs at most once per network condition, cached by
///   the fingerprint until `networkChanged()` drops the cache on a Wi-Fi/VPN/cellular
///   transition (failed probes retry on the same throttle as failed lookups).
/// - Self-correcting: on a fast failure, `API.request` calls `failover(afterFailing:for:)`,
///   which demotes that base for the current network and returns the instance's next-best one.
///
/// The resolved URL is purely runtime state and is never persisted, so it can never reach
/// iCloud, the App Group, or another device.
actor InstanceResolver {
    static let shared = InstanceResolver()

    private var state = ResolverRouting.State()

    /// Blocking `getaddrinfo` calls run here — a plain queue is the right executor for a
    /// syscall that can stall for ~30s, keeping it off this actor and the cooperative pool.
    private static let resolutionQueue = DispatchQueue(label: "io.ruddarr.url-resolution", qos: .utility, attributes: .concurrent)

    /// Returns the best base URL string for `instance` on the current network, and kicks off
    /// any pending hostname lookups and `/ping` probes in the background.
    func resolve(_ instance: Instance) -> String {
        let candidates = instance.candidateURLs

        guard candidates.count > 1 else {
            return candidates.first ?? instance.url
        }

        // Snapshot and registration happen in one non-suspending actor section, so the
        // fingerprint used to sync the caches is always the one the ranking saw.
        let snapshot = NetworkSnapshot.capture()
        let result = ResolverRouting.register(
            &state, candidates: candidates, snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
        )

        dispatchResolution(result.pending, snapshot: snapshot, epoch: state.epoch)
        dispatchProbes(result.probes, epoch: state.epoch)

        return result.ordered.first ?? candidates.first ?? instance.url
    }

    /// The base URL `resolve` would return right now, ranked from cached state only — a pure
    /// read for passive UI that claims no lookups and dispatches no probes.
    func currentSelection(for instance: Instance) -> String {
        let candidates = instance.candidateURLs

        guard candidates.count > 1 else {
            return candidates.first ?? instance.url
        }

        let snapshot = NetworkSnapshot.capture()
        let ordered = ResolverRouting.rank(
            &state, candidates: candidates, snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
        )

        return ordered.first ?? candidates.first ?? instance.url
    }

    /// The network changed (Wi-Fi/VPN/cellular). Drop everything learned about the old one so
    /// the next selection re-resolves once — catches transitions the subnet fingerprint can't
    /// tell apart (two different LANs sharing the same private subnet).
    func networkChanged() {
        ResolverRouting.networkChanged(&state)
    }

    /// Demotes the base that served `failedURL` and returns `instance`'s next-best candidate
    /// (same request path re-attached), or `nil` when there is nothing left to try. Only this
    /// instance's own candidates are ever considered, so a failed request can never be re-issued
    /// against another instance's host.
    func failover(afterFailing failedURL: URL, for instance: Instance) -> URL? {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return nil }

        let snapshot = NetworkSnapshot.capture()

        return ResolverRouting.failover(
            &state, afterFailing: failedURL.absoluteString, candidates: candidates,
            snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
        )
    }

    /// Clears any demotion for the base that served this URL — any HTTP response proves the host
    /// is reachable again. The `demotedUntil.isEmpty` check keeps the common (nothing-demoted)
    /// case off the `matchingBase` path.
    func noteSuccess(for url: URL, instance: Instance) {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return }

        guard !state.demotedUntil.isEmpty else { return }
        ResolverRouting.noteSuccess(&state, for: url.absoluteString, candidates: candidates)
    }

    /// A structured snapshot of the current network and, for each instance, why every candidate
    /// URL ranks where it does — unmasked, for the diagnostics screen to mask on demand.
    /// Read-only: it reflects what selection currently sees (cached resolutions, active
    /// demotions) and triggers no lookups or probes.
    func report(for instances: [Instance]) async -> NetworkReport {
        let facts = await NetworkMonitor.shared.pathFacts

        let snapshot = NetworkSnapshot.capture()
        let demoted = ResolverRouting.activeDemotions(&state, now: Date())
        let resolvedHosts = state.resolvedHosts
        let probes = state.probeOutcomes

        let entries = instances.map { instance -> NetworkReport.InstanceEntry in
            let candidates = instance.candidateURLs
            let resolved = ResolverRouting.cachedRoles(resolvedHosts, for: candidates)
            let ranked = NetworkInterfaces.ranking(
                candidates, snapshot: snapshot, demoted: demoted, resolved: resolved, probed: probes
            )
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
                    probe: probes[entry.base],
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
    /// Nonisolated so the non-`Sendable` dictionary never crosses the actor boundary: it runs
    /// on the caller and only awaits the `Sendable` report.
    nonisolated func diagnostics(for instances: [Instance]) async -> [String: Any] {
        let report = await report(for: instances)

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

    /// Probes each claimed base's unauthenticated `/ping` in the background and records the
    /// verdict for the current network. Selection never waits on this: the verdict lands in
    /// the cache and the next `resolve` call promotes a verified base.
    private func dispatchProbes(_ bases: [String], epoch: Int) {
        guard !bases.isEmpty else { return }

        for base in bases {
            Task(priority: .utility) {
                let outcome = await Self.probe(base)
                recordProbe(base: base, epoch: epoch, outcome: outcome)
            }
        }
    }

    private func recordProbe(base: String, epoch: Int, outcome: ProbeOutcome) {
        ResolverRouting.recordProbe(&state, base: base, epoch: epoch, outcome: outcome, now: Date())
    }

    /// Ephemeral (no cookies, no cache) and bounded by the probe timeout, so an unreachable
    /// VLAN address costs one silent, short-lived connection attempt in the background.
    private static let probeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = ResolverRouting.probeTimeout
        configuration.timeoutIntervalForResource = ResolverRouting.probeTimeout
        configuration.waitsForConnectivity = false

        return URLSession(configuration: configuration)
    }()

    private static func probe(_ base: String) async -> ProbeOutcome {
        guard let url = ResolverRouting.probeURL(for: base) else {
            return ProbeOutcome(reachable: false)
        }

        let clock = ContinuousClock()
        let started = clock.now

        guard let (data, response) = try? await probeSession.data(from: url),
              let http = response as? HTTPURLResponse,
              ResolverRouting.probeVerdict(
                  status: http.statusCode,
                  finalHost: http.url?.host(percentEncoded: false),
                  probedHost: url.host(percentEncoded: false),
                  body: data
              )
        else {
            return ProbeOutcome(reachable: false)
        }

        let elapsed = started.duration(to: clock.now)
        let latency = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18

        return ProbeOutcome(reachable: true, latency: latency)
    }

    private func dispatchResolution(_ hosts: [String], snapshot: NetworkSnapshot, epoch: Int) {
        guard !hosts.isEmpty else { return }

        for host in hosts {
            Task(priority: .utility) {
                let resolved = await Self.lookup(host, snapshot: snapshot)
                recordResolution(host: host, epoch: epoch, resolved: resolved)
            }
        }
    }

    private func recordResolution(host: String, epoch: Int, resolved: ResolvedHost?) {
        ResolverRouting.recordResolution(&state, host: host, epoch: epoch, resolved: resolved, now: Date())
    }

    /// Resolves and classifies `host` on the dedicated queue, suspending the caller instead of
    /// blocking it while `getaddrinfo` waits on DNS.
    private static func lookup(_ host: String, snapshot: NetworkSnapshot) async -> ResolvedHost? {
        await withCheckedContinuation { continuation in
            resolutionQueue.async {
                let outcome = resolveAddresses(host)
                let resolved = outcome.ok
                    ? NetworkInterfaces.classify(ipv4: outcome.ipv4, ipv6: outcome.ipv6, snapshot: snapshot)
                    : nil

                continuation.resume(returning: resolved)
            }
        }
    }

    private static func resolveAddresses(_ host: String) -> (ipv4: [UInt32], ipv6: [in6_addr], ok: Bool) {
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
