import Foundation

/// Chooses which of an instance's URLs to use for the current network, and recovers fast when
/// that choice turns out to be wrong. The routing state machine lives in `ResolverRouting`
/// (pure, unit-tested); this actor owns the state — serialized by actor isolation — and runs
/// the background DNS lookups and `/ping` probes.
///
/// - `resolve(_:)` ranks against a fresh snapshot and claims pending lookups and probes;
///   `currentSelection(for:)` is the passive read for UI and generates no traffic.
/// - A hostname is classified by where its records point, so a split-horizon name ranks as
///   on-link LAN; an off-link private candidate is promoted above remote once an
///   unauthenticated `/ping` proves the router routes into its VLAN.
/// - Lookups and probes run at most once per network, cached by the fingerprint until
///   `networkChanged()` drops them.
/// - On a fast failure `API.request` calls `failover(afterFailing:for:)` to demote that base.
/// - `reachableWebURL(for:)` answers a different question — which URL a *browser* can open.
///
/// The resolved URL is purely runtime state and is never persisted, so it can never reach
/// iCloud, the App Group, or another device.
actor InstanceResolver {
    static let shared = InstanceResolver()

    private var state = ResolverRouting.State()

    /// Blocking `getaddrinfo` calls run here, off this actor and the cooperative pool.
    private static let resolutionQueue = DispatchQueue(label: "io.ruddarr.url-resolution", qos: .utility, attributes: .concurrent)

    /// The best base URL for `instance` on the current network; kicks off any pending hostname
    /// lookups and `/ping` probes in the background.
    func resolve(_ instance: Instance) -> String {
        let candidates = instance.candidateURLs

        guard candidates.count > 1 else {
            return candidates.first ?? instance.url
        }

        // One non-suspending section, so the fingerprint syncing the caches is the one ranking saw.
        let snapshot = NetworkSnapshot.capture()
        let result = ResolverRouting.register(
            &state, candidates: candidates, snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
        )

        dispatchResolution(result.pending, snapshot: snapshot, epoch: state.epoch)
        dispatchProbes(result.probes, epoch: state.epoch)

        return result.ordered.first ?? candidates.first ?? instance.url
    }

    /// Every candidate of `instance`, best first, from cached state only — claims no lookups and
    /// dispatches no probes. For passive UI and the web check, which wants the whole ladder.
    func rankedCandidates(for instance: Instance) -> [String] {
        let candidates = instance.candidateURLs

        guard candidates.count > 1 else {
            return candidates
        }

        let snapshot = NetworkSnapshot.capture()
        let ordered = ResolverRouting.rank(
            &state, candidates: candidates, snapshot: snapshot, fingerprint: snapshot.fingerprint, now: Date()
        )

        return ordered.isEmpty ? candidates : ordered
    }

    /// The base URL `resolve` would return right now, from cached state only — no side effects.
    func currentSelection(for instance: Instance) -> String {
        rankedCandidates(for: instance).first ?? instance.url
    }

    /// The network changed (Wi-Fi/VPN/cellular). Drops everything learned about the old one —
    /// catches transitions the fingerprint can't tell apart (two LANs sharing one subnet).
    func networkChanged() {
        ResolverRouting.networkChanged(&state)
    }

    /// Demotes the base that served `failedURL` and returns `instance`'s next-best candidate
    /// (same request path re-attached), or `nil`. Only this instance's own candidates are
    /// considered, so a failed request can never be re-issued against another instance's host.
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
    /// is reachable again. The `demotedUntil.isEmpty` check short-circuits the common case.
    func noteSuccess(for url: URL, instance: Instance) {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return }

        guard !state.demotedUntil.isEmpty else { return }
        ResolverRouting.noteSuccess(&state, for: url.absoluteString, candidates: candidates)
    }

    /// The instance's web interface at a URL worth handing to a browser, or `nil` when nothing
    /// answered anywhere — which is what disables the web button in `InstanceView`. Selection
    /// can't answer this: it knows where the *app* should talk, having authenticated.
    ///
    /// A verified `/ping` wins, but a host that merely answered (a redirect to an identity
    /// provider, a 403, a login page) is never written off: Safari may hold a session this check
    /// cannot see. Every candidate is checked so diagnostics can show a verdict for each; the
    /// checks run concurrently, at most once per `resolveRetryInterval`, and never feed routing.
    func reachableWebURL(for instance: Instance) async -> URL? {
        let candidates = rankedCandidates(for: instance)
        let epoch = state.epoch
        let pending = ResolverRouting.claimWebChecksNeeded(&state, candidates, now: Date())

        if !pending.isEmpty {
            let outcomes = await withTaskGroup(of: (String, ProbeOutcome).self) { group in
                for base in pending {
                    group.addTask { (base, await Self.probe(base, via: Self.webCheckSession)) }
                }

                var results: [(String, ProbeOutcome)] = []
                for await result in group { results.append(result) }
                return results
            }

            let now = Date()

            for (base, outcome) in outcomes {
                ResolverRouting.recordWebCheck(&state, base: base, epoch: epoch, outcome: outcome, now: now)
            }
        }

        return ResolverRouting.webSelection(candidates, outcomes: state.webOutcomes)
            .flatMap { URL(string: $0) }
    }

    /// Doesn't follow redirects, so a candidate is judged only by the host that was asked.
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            nil
        }
    }

    /// Ephemeral (no cookies, no cache) so nothing stored can make a dead URL look alive, and
    /// more patient than the routing probe: a slow host wrongly called dead loses the button.
    private static let webCheckSession: URLSession = {
        let timeout: TimeInterval = 5

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false

        return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }()

    /// A structured snapshot of the current network and why every candidate ranks where it does —
    /// unmasked, for the diagnostics screen to mask on demand. Triggers no lookups or probes.
    func report(for instances: [Instance]) async -> NetworkReport {
        let facts = await NetworkMonitor.shared.pathFacts

        let snapshot = NetworkSnapshot.capture()
        let demoted = ResolverRouting.activeDemotions(&state, now: Date())
        let resolvedHosts = state.resolvedHosts
        let probes = state.probeOutcomes
        let webChecks = state.webOutcomes

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
                    web: webChecks[entry.base],
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

    /// The masked, Sentry-shaped rendering of `report(for:)`. Nonisolated so the non-`Sendable`
    /// dictionary is built on the caller and never crosses the actor boundary.
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

    /// Probes each claimed base's unauthenticated `/ping` in the background. Selection never
    /// waits: the verdict lands in the cache and the next `resolve` promotes a verified base.
    private func dispatchProbes(_ bases: [String], epoch: Int) {
        guard !bases.isEmpty else { return }

        for base in bases {
            Task(priority: .utility) {
                let outcome = await Self.probe(base, via: Self.probeSession)
                recordProbe(base: base, epoch: epoch, outcome: outcome)
            }
        }
    }

    private func recordProbe(base: String, epoch: Int, outcome: ProbeOutcome) {
        ResolverRouting.recordProbe(&state, base: base, epoch: epoch, outcome: outcome, now: Date())
    }

    /// Ephemeral (no cookies, no cache) and bounded by the probe timeout, so an unreachable
    /// address costs one short-lived background connection attempt.
    private static let probeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = ResolverRouting.probeTimeout
        configuration.timeoutIntervalForResource = ResolverRouting.probeTimeout
        configuration.waitsForConnectivity = false

        return URLSession(configuration: configuration)
    }()

    /// One candidate's `/ping`, timed and unauthenticated by design — no secret may ride along to
    /// an unverified address, and the instance's own credentials can't vouch for an address a
    /// browser would be turned away from. `reachable` is the strict verdict (HTTP success, from
    /// the host that was asked, `{"status": "OK"}`); `answered` records any response at all.
    private static func probe(_ base: String, via session: URLSession) async -> ProbeOutcome {
        guard let url = ResolverRouting.probeURL(for: base) else {
            return ProbeOutcome(reachable: false)
        }

        let clock = ContinuousClock()
        let started = clock.now

        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse
        else {
            return ProbeOutcome(reachable: false)
        }

        let elapsed = started.duration(to: clock.now)
        let latency = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18

        let verified = ResolverRouting.probeVerdict(
            status: http.statusCode,
            finalHost: http.url?.host(percentEncoded: false),
            probedHost: url.host(percentEncoded: false),
            body: data
        )

        return ProbeOutcome(reachable: verified, answered: true, latency: verified ? latency : nil)
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

    /// Resolves and classifies `host` on the dedicated queue, suspending the caller rather than
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
