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

    /// The device's subnets annotated with their interface (`192.168.1.0/24 (en0)`) — shared by
    /// the diagnostics screen and the export so the two renderings can't drift.
    func subnetRowsV4(_ mask: NetworkDiagnosticsMask) -> String {
        mask.list(deviceV4.map { annotated(mask.cidr($0.cidr), interface: $0.interface) })
    }

    func subnetRowsV6(_ mask: NetworkDiagnosticsMask) -> String {
        mask.list(deviceV6.map { annotated(mask.cidr($0.cidr), interface: $0.interface) })
    }

    /// The IPv4 default gateway(s) with their interface (`192.168.1.1 (en0)`).
    func gatewayRows(_ mask: NetworkDiagnosticsMask) -> String {
        mask.list(gatewaysV4.map { annotated(mask.ip($0.address), interface: $0.interface) })
    }

    private func annotated(_ value: String, interface: String) -> String {
        interface.isEmpty ? value : "\(value) (\(interface))"
    }

    func exportText(masked: Bool) -> String {
        let mask = NetworkDiagnosticsMask(masked: masked)
        var lines: [String] = ["# Ruddarr Diagnostics"]

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            lines.append("Version: \(version) (\(build))")
        }

        lines.append("")
        lines.append("[Device]")
        lines.append("Connection: \(connection)")
        lines.append("Low Data Mode: \(constrained ? "on" : "off")")
        lines.append("Local Network: \(localNetworkDenied ? "denied" : "allowed")")
        lines.append("IPv4 Address: \(mask.list(deviceV4.map { mask.ip(NetworkInterfaces.string(fromIPv4: $0.address)) }))")
        lines.append("IPv4 Subnets: \(subnetRowsV4(mask))")
        lines.append("IPv6 Address: \(mask.list(deviceV6.map { mask.ip(NetworkInterfaces.string(fromIPv6Bytes: $0.address)) }))")
        lines.append("IPv6 Subnets: \(subnetRowsV6(mask))")
        lines.append("Gateway: \(gatewayRows(mask))")
        lines.append("Network ID: \(masked ? "hidden" : fingerprint)")
        lines.append("Tailscale: \(tailnetUp ? "up" : "down")")

        for entry in instances {
            lines.append("")
            lines.append("[\(entry.label)]")
            lines.append("Type: \(entry.type)")
            lines.append("Mode: \(entry.mode)")
            lines.append("Context: \(entry.contextKey)")
            lines.append("Selected: \(mask.url(entry.selected))")

            for candidate in entry.candidates {
                lines.append("")
                lines.append("- URL: \(mask.url(candidate.url))")
                lines.append("  Host: \(mask.host(of: candidate.url))")
                lines.append("  Role: \(candidate.roleDescription)")
                lines.append("  Score: \(candidate.score)")

                if candidate.hasHostname {
                    lines.append("  Classification: \(candidate.resolved ? "resolved" : "lexical")")
                    lines.append("  Resolved IPs: \(mask.list(candidate.addresses.map(mask.ip)))")
                }

                if let probeDescription = candidate.probeDescription {
                    lines.append("  Probe: \(probeDescription)")
                }

                lines.append("  Position: \(candidate.primary ? "primary" : "alternate")")
                lines.append("  Demoted: \(candidate.demoted ? "yes" : "no")")
                lines.append("  Selected: \(candidate.selected ? "yes" : "no")")
            }
        }

        return lines.joined(separator: "\n")
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
}
