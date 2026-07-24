import SwiftUI
import CloudKit

struct DiagnosticsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var report: NetworkReport?
    @State private var appDiagnostics: AppDiagnostics?
    @State private var failedRequests: [FailedRequest] = []
    @State private var networkToken: UUID?

    @State private var masked: Bool = true

    @State private var collapsedInstances: Set<Instance.ID> = []
    @State private var expandedCandidates: Set<String> = []

    @AppStorage("elevator", store: dependencies.store) var elevator: Bool = true

    var body: some View {
        diagnosticsList
            .animation(.snappy, value: masked)
            .toolbar {
                toolbarMaskButton
                toolbarShareButton
            }
            .onBecomeActive {
                appDiagnostics = await AppDiagnostics.load()
            }
            .task {
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            .task(id: networkToken) {
                guard networkToken != nil else { return }

                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .networkChanged)) { _ in
                networkToken = UUID()
            }
    }

    @ViewBuilder
    var diagnosticsList: some View {
        #if os(macOS)
            Form {
                content
            }
            .formStyle(.grouped)
        #else
            List {
                content
            }
            .listStyle(.sidebar)
        #endif
    }

    @ViewBuilder
    var content: some View {
        appSection
        deviceSection
        networkSection

        if let report {
            ForEach(report.instances) { entry in
                instanceSection(entry)
            }
        }

        requestsSection
    }

    @ViewBuilder
    var requestsSection: some View {
        if !failedRequests.isEmpty {
            Section {
                ForEach(failedRequests) { request in
                    requestRow(request)
                }
            } header: {
                Text(verbatim: "Failed Requests")
            }
        }
    }

    var appSection: some View {
        Section {
            Toggle(isOn: $elevator) {
                Text(verbatim: "Elevator Music")
            }

//            if let appDiagnostics {
//                networkDiagnosticsRow("Locale", appDiagnostics.locale)
//                networkDiagnosticsRow("Region", appDiagnostics.region)
//            }
        } header: {
            Text(verbatim: "App")
        }
    }

    @ViewBuilder
    var deviceSection: some View {
        if let report {
            Section {
                networkDiagnosticsRow("Connection", report.connection)
                networkDiagnosticsRow("Local Network", report.localNetworkDenied ? "denied" : "allowed")
                networkDiagnosticsRow("Tailscale", report.tailnetUp ? "up" : "down")
            } header: {
                Text(verbatim: "Device")
            }
        }
    }

    @ViewBuilder
    var networkSection: some View {
        if let report {
            Section {
                networkDiagnosticsRow("IPv4 Address", mask.list(report.deviceV4.map { mask.ip(NetworkInterfaces.string(fromIPv4: $0.address)) }))
                networkDiagnosticsRow("IPv4 Subnets", report.subnetRowsV4(mask))

                if !report.deviceV6.isEmpty {
                    networkDiagnosticsRow("IPv6 Address", mask.list(report.deviceV6.map { mask.ip(NetworkInterfaces.string(fromIPv6Bytes: $0.address)) }))
                    networkDiagnosticsRow("IPv6 Subnets", report.subnetRowsV6(mask))
                }

                networkDiagnosticsRow("Gateway", report.lanGatewayRows(mask))
            } header: {
                Text(verbatim: "Network")
            }
        }
    }

    var mask: NetworkDiagnosticsMask {
        NetworkDiagnosticsMask(masked: masked)
    }

    var highlighter: NetworkDiagnosticsHighlighter {
        NetworkDiagnosticsHighlighter(subnets: report?.deviceV4 ?? [])
    }

    var toolbarMaskButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                masked.toggle()
            } label: {
                Image(systemName: masked ? "eye" : "eye.slash")
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.snappy, value: masked)
            }
            .tint(.primary)
        }
    }

    @ToolbarContentBuilder
    var toolbarShareButton: some ToolbarContent {
        if let report {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: NetworkDiagnosticsExport(
                        text: report.exportText(
                            masked: masked,
                            app: appDiagnostics?.exportLines() ?? [],
                            failed: failedRequestsExportLines()
                        )
                    ),
                    preview: SharePreview(exportFilename)
                )
                .tint(.primary)
            }
        }
    }

    func instanceSection(_ entry: NetworkReport.InstanceEntry) -> some View {
        Section(isExpanded: expansion(for: entry.id)) {
            ForEach(entry.candidates) { candidate in
                DisclosureGroup(isExpanded: candidateExpansion(for: "\(entry.id)|\(candidate.url)")) {
                    networkDiagnosticsRow("Host", candidateHostText(candidate))
                    networkDiagnosticsRow("Role", roleText(candidate))
                    networkDiagnosticsRow("Score", "\(candidate.score)")

                    if candidate.hasHostname {
                        networkDiagnosticsRow("Resolved IPs", candidateAddressesText(candidate))
                    }

                    if candidate.probeDescription != nil {
                        networkDiagnosticsRow("Probe", probeText(candidate))
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(verbatim: mask.url(candidate.url))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if candidate.selected {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: entry.label)
        }
    }

    func expansion(for id: Instance.ID) -> Binding<Bool> {
        Binding(
            get: {
                !collapsedInstances.contains(id)
            },
            set: { isExpanded in
                if isExpanded {
                    collapsedInstances.remove(id)
                } else {
                    collapsedInstances.insert(id)
                }
            }
        )
    }

    func candidateExpansion(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                expandedCandidates.contains(key)
            },
            set: { isExpanded in
                if isExpanded {
                    expandedCandidates.insert(key)
                } else {
                    expandedCandidates.remove(key)
                }
            }
        )
    }

    func candidateHostText(_ candidate: NetworkReport.Candidate) -> Text {
        let shown = mask.host(of: candidate.url)
        guard candidate.role == .lan else {
            return Text(verbatim: shown)
        }

        return highlighter.address(shown, highlightMismatch: highlightsMismatch(candidate))
    }

    func candidateAddressesText(_ candidate: NetworkReport.Candidate) -> Text {
        let shown = candidate.addresses.map(mask.ip)

        guard candidate.role == .lan else {
            return Text(verbatim: shown.isEmpty ? "none" : shown.joined(separator: ", "))
        }

        return highlighter.addressList(shown, highlightMismatch: highlightsMismatch(candidate))
    }

    func highlightsMismatch(_ candidate: NetworkReport.Candidate) -> Bool {
        !candidate.onLink && candidate.probe?.reachable != true
    }

    func roleText(_ candidate: NetworkReport.Candidate) -> Text {
        var value = AttributedString(candidate.roleDescription)

        if candidate.role == .lan {
            value.foregroundColor = candidate.onLink || candidate.probe?.reachable == true ? .green : .orange
        }

        return Text(value)
    }

    func probeText(_ candidate: NetworkReport.Candidate) -> Text {
        var value = AttributedString(candidate.probeDescription ?? "")
        value.foregroundColor = candidate.probe?.reachable == true ? .green : .orange

        return Text(value)
    }

    func refresh() async {
        let instances = settings.configuredInstances

        for instance in instances {
            _ = await InstanceResolver.shared.resolve(instance)
        }

        let updated = await InstanceResolver.shared.report(for: instances)

        if updated != report {
            report = updated
        }

        let failures = await RequestDiagnostics.shared.snapshot()

        if failures != failedRequests {
            failedRequests = failures
        }
    }

    func failedRequestsExportLines() -> [String] {
        guard !failedRequests.isEmpty else { return [] }

        var lines: [String] = ["", "[Failed Requests]"]

        for request in failedRequests {
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

    private func networkDiagnosticsRow(_ label: String, _ value: String) -> some View {
        networkDiagnosticsRow(label, Text(verbatim: value))
    }

    private func networkDiagnosticsRow(_ label: String, _ valueText: Text) -> some View {
        LabeledContent {
            valueText
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .monospaced()
                .font(.subheadline)
                .tracking(-0.5)
        } label: {
            Text(verbatim: label)
        }
    }

    private func requestRow(_ request: FailedRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(verbatim: request.badge)
                    .fontWeight(.semibold)

                Bullet()
                Text(verbatim: request.method)

                if let instance = request.instance {
                    Bullet()
                    Text(verbatim: instance)
                        .lineLimit(1)
                }

                Spacer()

                Text(request.date.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text(verbatim: mask.url(request.url))
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let detail = request.detail, !detail.isEmpty {
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .textSelection(.enabled)
    }
}

#Preview {
    dependencies.router.selectedTab = .settings
    dependencies.router.settingsPath.append(SettingsView.Path.diagnostics)

    var radarr = Instance.radarrDummy
    radarr.id = UUID()
    radarr.label = "Radarr"

    var sonarr = Instance.sonarrDummy
    sonarr.id = UUID()

    InstancesStore.shared.setInstances([radarr, sonarr])

    return ContentView().withAppState()
}
