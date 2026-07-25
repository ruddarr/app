import Foundation

struct NetworkReport: Equatable, Sendable {
    struct Candidate: Identifiable, Equatable, Sendable {
        let url: String
        let role: InstanceURLRole
        let onLink: Bool
        let score: Int
        let resolved: Bool
        let addresses: [String]
        let probe: ProbeOutcome?
        let demoted: Bool
        let primary: Bool
        let selected: Bool

        var id: String { url }

        var roleDescription: String {
            switch role {
            case .lan:
                if onLink { return "LAN (on-link)" }
                return probe?.reachable == true ? "LAN (routed)" : "(LAN off-link)"
            case .tailscale: return "Tailscale"
            case .remote: return "remote"
            }
        }

        var probeDescription: String? {
            guard let probe else { return nil }
            guard probe.reachable else { return "unreachable" }
            guard let latency = probe.latency else { return "reachable" }

            return "reachable (\(Int((latency * 1_000).rounded())) ms)"
        }

        var summary: String {
            var parts = [roleDescription, "score \(score)", resolved ? "resolved" : "lexical"]
            if let probeDescription { parts.append("probe \(probeDescription)") }
            if demoted { parts.append("demoted") }
            if primary { parts.append("primary") }

            return parts.joined(separator: ", ")
        }

        var hasHostname: Bool {
            guard let host = NetworkInterfaces.host(of: url) else { return false }
            return NetworkInterfaces.parseIPv4(host) == nil && NetworkInterfaces.parseIPv6(host) == nil
        }
    }

    struct InstanceEntry: Identifiable, Equatable, Sendable {
        let id: Instance.ID
        let label: String
        let type: String
        let mode: String
        let contextKey: String
        let selected: String
        let candidates: [Candidate]
    }

    let tailnetUp: Bool
    let localNetworkDenied: Bool

    let connection: String
    let constrained: Bool
    let expensive: Bool

    let lanV4: [String]
    let lanV6: [String]

    let deviceV4: [IPv4Subnet]
    let deviceV6: [IPv6Subnet]

    let gatewaysV4: [RouteTable.Gateway]

    let fingerprint: String

    let instances: [InstanceEntry]

    /// The default gateway(s) on the device's own LAN interfaces — the `en*` links that carry an
    /// on-link subnet, dropping cellular/VPN default routes (`pdp*`, `utun*`) irrelevant to
    /// reaching a LAN instance.
    var lanGateways: [RouteTable.Gateway] {
        let interfaces = Set(deviceV4.map(\.interface)).union(deviceV6.map(\.interface))
        return gatewaysV4.filter { interfaces.contains($0.interface) }
    }
}

struct NetworkDiagnosticsMask {
    let masked: Bool

    func list(_ values: [String]) -> String {
        values.isEmpty ? "none" : values.joined(separator: ", ")
    }

    func host(of base: String) -> String {
        guard let host = NetworkInterfaces.host(of: base) else { return "invalid" }
        return !masked ? host : maskedIP(host)
    }

    func url(_ value: String) -> String { !masked ? urlHidingUserinfo(value) : maskedURL(value) }
    func ip(_ value: String) -> String { !masked ? value : maskedIP(value) }
    func cidr(_ value: String) -> String { !masked ? value : maskedCIDR(value) }

    /// Free text rendered next to a request URL: masks embedded scheme-prefixed URLs, plus bare
    /// occurrences of the request's host — TLS errors quote the hostname without a scheme.
    func text(_ value: String, for url: String) -> String {
        guard masked else { return value }

        var result = maskURLs(in: value)

        if let host = NetworkInterfaces.host(of: url) {
            result = result.replacing(host, with: maskedIP(host))
        }

        return result
    }
}
