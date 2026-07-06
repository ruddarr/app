import Foundation

/// Everything URL selection sees on the current network, unmasked: the device's snapshot
/// facts plus every candidate's standing per instance. Rendered masked into the Sentry
/// context by `diagnostics(for:)` and mask-toggled by `DiagnosticsView`.
struct NetworkReport: Equatable, Sendable {
    struct Candidate: Identifiable, Equatable, Sendable {
        let url: String
        let role: InstanceURLRole
        let onLink: Bool
        let score: Int
        let resolved: Bool
        let addresses: [String]
        let demoted: Bool
        let primary: Bool
        let selected: Bool

        var id: String { url }

        var roleDescription: String {
            switch role {
            case .lan: return onLink ? "on-link LAN" : "off-link LAN"
            case .tailscale: return "Tailscale"
            case .remote: return "remote"
            }
        }

        var summary: String {
            var parts = [roleDescription, "score \(score)", resolved ? "resolved" : "lexical"]
            if demoted { parts.append("demoted") }
            if primary { parts.append("primary") }

            return parts.joined(separator: ", ")
        }

        /// Whether the URL's host is a DNS name rather than an IP literal — the only case where
        /// "resolved IPs" is meaningful, since a literal address has nothing to resolve.
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
    let lanV4: [String]
    let lanV6: [String]

    /// The device's own LAN interfaces, structured — the reference the diagnostics screen colors
    /// each candidate address against, octet by octet, and the source of the device host-address
    /// rows. `lanV4`/`lanV6` above are the same interfaces rendered as `network/prefix` strings.
    let deviceV4: [IPv4Subnet]
    let deviceV6: [IPv6Subnet]

    /// The network identity token demotions and resolutions are scoped to (see `NetworkSnapshot`).
    let fingerprint: String

    let instances: [InstanceEntry]
}

/// String masking for the diagnostics screen and its shared report: applies the `Privacy` helpers
/// when `masked`, and passes values through untouched otherwise. Shared by `DiagnosticsView`
/// (row values) and `NetworkReport.exportText`, so both mask identically.
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

extension NetworkReport {
    /// The full plaintext report shared from the diagnostics screen, masked or plain. The screen
    /// shows a trimmed subset of these fields; the report keeps every one so a bug report is
    /// complete. `Resolved IPs` is emitted only for hostname candidates (a literal IP has nothing
    /// to resolve) — the same rule the UI uses.
    func exportText(masked: Bool) -> String {
        let mask = NetworkDiagnosticsMask(masked: masked)
        var lines: [String] = ["# Ruddarr Diagnostics"]

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            lines.append("Version: \(version) (\(build))")
        }

        lines.append("")
        lines.append("[Device]")
        lines.append("Local Network: \(localNetworkDenied ? "denied" : "allowed")")
        lines.append("IPv4 Address: \(mask.list(deviceV4.map { mask.ip(NetworkInterfaces.string(fromIPv4: $0.address)) }))")
        lines.append("IPv4 Subnets: \(mask.list(lanV4.map(mask.cidr)))")
        lines.append("IPv6 Address: \(mask.list(deviceV6.map { mask.ip(NetworkInterfaces.string(fromIPv6Bytes: $0.address)) }))")
        lines.append("IPv6 Subnets: \(mask.list(lanV6.map(mask.cidr)))")
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

                lines.append("  Position: \(candidate.primary ? "primary" : "alternate")")
                lines.append("  Demoted: \(candidate.demoted ? "yes" : "no")")
                lines.append("  Selected: \(candidate.selected ? "yes" : "no")")
            }
        }

        return lines.joined(separator: "\n")
    }
}
