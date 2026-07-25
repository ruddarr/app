import Foundation

struct DiagnosticsReport: Sendable {
    let sections: [FieldSection]
    let instances: [NetworkReport.InstanceEntry]
    let failedRequests: [FailedRequest]

    init(report: NetworkReport?, app: AppDiagnostics?, requests: [FailedRequest]) {
        var sections: [FieldSection] = [Self.appSection(app)]

        if let app {
            sections.append(Self.notificationsSection(app))
        }

        if let report {
            sections.append(Self.deviceSection(report))
            sections.append(Self.networkSection(report))
        }

        self.sections = sections
        self.instances = report?.instances ?? []
        self.failedRequests = requests
    }

    private static func appSection(_ app: AppDiagnostics?) -> FieldSection {
        var rows: [DiagnosticRow] = [
            DiagnosticRow("Elevator Music", .plain(""), control: .elevator, appearance: .screenOnly),
        ]

        if let app {
            rows.append(DiagnosticRow("Locale", .plain(app.locale), appearance: .exportOnly))
            rows.append(DiagnosticRow("Region", .plain(app.region), appearance: .exportOnly))
        }

        return FieldSection("App", rows)
    }

    private static func notificationsSection(_ app: AppDiagnostics) -> FieldSection {
        FieldSection("Notifications", [
            DiagnosticRow("Subscription", .plain(app.subscription), appearance: .exportOnly),
            DiagnosticRow("Entitled", .plain(app.entitled), appearance: .exportOnly),
            DiagnosticRow("Entitled At", .plain(app.entitledAt), appearance: .exportOnly),
            DiagnosticRow("Push Authorization", .plain(app.pushAuthorization), appearance: .exportOnly),
            DiagnosticRow("iCloud Account", .plain(app.iCloudAccount), appearance: .exportOnly),
        ])
    }

    private static func deviceSection(_ report: NetworkReport) -> FieldSection {
        FieldSection("Device", [
            DiagnosticRow("Connection", .plain(report.connection)),
            DiagnosticRow("Low Data Mode", .plain(report.constrained ? "on" : "off"), appearance: .exportOnly),
            DiagnosticRow("Local Network", .plain(report.localNetworkDenied ? "denied" : "allowed")),
            DiagnosticRow("Tailscale", .plain(report.tailnetUp ? "up" : "down")),
        ])
    }

    private static func networkSection(_ report: NetworkReport) -> FieldSection {
        let v6: DiagnosticVisibility = report.deviceV6.isEmpty ? .exportOnly : .both

        return FieldSection("Network", [
            DiagnosticRow("IPv4 Address", .list(report.deviceV4.map { .ip(NetworkInterfaces.string(fromIPv4: $0.address)) })),
            DiagnosticRow("IPv4 Subnets", .list(report.deviceV4.map { .annotated(.cidr($0.cidr), interface: $0.interface) })),
            DiagnosticRow("IPv6 Address", .list(report.deviceV6.map { .ip(NetworkInterfaces.string(fromIPv6Bytes: $0.address)) }), appearance: v6),
            DiagnosticRow("IPv6 Subnets", .list(report.deviceV6.map { .annotated(.cidr($0.cidr), interface: $0.interface) }), appearance: v6),
            DiagnosticRow("Gateway", .list(report.lanGateways.map { .annotated(.ip($0.address), interface: $0.interface) }), appearance: .screenOnly),
            DiagnosticRow("Gateway", .list(report.gatewaysV4.map { .annotated(.ip($0.address), interface: $0.interface) }), appearance: .exportOnly),
            DiagnosticRow("Network ID", .fingerprint(report.fingerprint), appearance: .exportOnly),
        ])
    }
}

struct FieldSection: Identifiable, Sendable {
    let title: String
    let rows: [DiagnosticRow]

    init(_ title: String, _ rows: [DiagnosticRow]) {
        self.title = title
        self.rows = rows
    }

    var id: String { title }
    var screenRows: [DiagnosticRow] { rows.filter { $0.appearance != .exportOnly } }
    var exportRows: [DiagnosticRow] { rows.filter { $0.appearance != .screenOnly } }
}

struct DiagnosticRow: Identifiable, Sendable {
    let label: String
    let value: DiagnosticValue
    let control: DiagnosticControl?
    let appearance: DiagnosticVisibility

    init(_ label: String, _ value: DiagnosticValue, control: DiagnosticControl? = nil, appearance: DiagnosticVisibility = .both) {
        self.label = label
        self.value = value
        self.control = control
        self.appearance = appearance
    }

    var id: String { "\(label)|\(appearance)" }
}

enum DiagnosticVisibility: Sendable, Hashable { case both, screenOnly, exportOnly }

enum DiagnosticControl: Sendable { case elevator }

enum DiagnosticValue: Sendable {
    case plain(String)
    case url(String)
    case ip(String)
    case cidr(String)
    case fingerprint(String)
    indirect case annotated(DiagnosticValue, interface: String)
    case list([DiagnosticValue])

    func string(masked: Bool) -> String {
        render(NetworkDiagnosticsMask(masked: masked))
    }

    private func render(_ mask: NetworkDiagnosticsMask) -> String {
        switch self {
        case .plain(let value): return value
        case .url(let value): return mask.url(value)
        case .ip(let value): return mask.ip(value)
        case .cidr(let value): return mask.cidr(value)
        case .fingerprint(let value): return mask.masked ? "hidden" : value
        case .annotated(let base, let interface):
            let rendered = base.render(mask)
            return interface.isEmpty ? rendered : "\(rendered) (\(interface))"
        case .list(let items):
            return mask.list(items.map { $0.render(mask) })
        }
    }
}
