import Foundation

enum DiagnosticsExport {
    static func text(from report: DiagnosticsReport, masked: Bool) -> String {
        var lines: [String] = ["# Ruddarr Diagnostics"]

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            lines.append("Version: \(version) (\(build))")
        }

        for section in report.sections {
            let rows = section.exportRows
            guard !rows.isEmpty else { continue }

            lines.append("")
            lines.append("[\(section.title)]")

            for row in rows {
                lines.append("\(row.label): \(row.value.string(masked: masked))")
            }
        }

        let mask = NetworkDiagnosticsMask(masked: masked)

        for instance in report.instances {
            lines.append("")
            lines.append("[\(instance.label)]")
            lines.append("Type: \(instance.type)")
            lines.append("Mode: \(instance.mode)")
            lines.append("Context: \(instance.contextKey)")
            lines.append("Selected: \(mask.url(instance.selected))")

            for candidate in instance.candidates {
                lines.append(contentsOf: candidateLines(candidate, mask))
            }
        }

        lines.append(contentsOf: failedRequestLines(report.failedRequests, mask))

        return lines.joined(separator: "\n")
    }

    private static func candidateLines(_ candidate: NetworkReport.Candidate, _ mask: NetworkDiagnosticsMask) -> [String] {
        var lines: [String] = [
            "",
            "- URL: \(mask.url(candidate.url))",
            "  Host: \(mask.host(of: candidate.url))",
            "  Role: \(candidate.roleDescription)",
            "  Score: \(candidate.score)",
        ]

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

        return lines
    }

    private static func failedRequestLines(_ requests: [FailedRequest], _ mask: NetworkDiagnosticsMask) -> [String] {
        guard !requests.isEmpty else { return [] }

        var lines: [String] = ["", "[Failed Requests]"]

        for request in requests {
            var parts = [request.date.formatted(date: .omitted, time: .standard), request.method, request.badge]
            if let instance = request.instance { parts.append("(\(instance))") }

            lines.append("- \(parts.joined(separator: " "))")
            lines.append("  URL: \(mask.url(request.url))")

            if let detail = request.detail, !detail.isEmpty {
                lines.append("  Error: \(detail)")
            }
        }

        return lines
    }
}
