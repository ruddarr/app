import SwiftUI
import CloudKit

struct DiagnosticsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var report: NetworkReport?
    @State private var appDiagnostics: AppDiagnostics?
    @State private var masked: Bool = true
    @State private var collapsedInstances: Set<Instance.ID> = []
    @State private var expandedCandidates: Set<String> = []
    @State private var networkToken: UUID?

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
        app
        // notifications
        device
        network

        if let report {
            ForEach(report.instances) { entry in
                instanceSection(entry)
            }
        }
    }

    var app: some View {
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

//    @ViewBuilder
//    var notifications: some View {
//        if let appDiagnostics {
//            Section {
//                networkDiagnosticsRow("Subscription", appDiagnostics.subscription)
//                networkDiagnosticsRow("Entitled", appDiagnostics.entitled)
//                networkDiagnosticsRow("Entitled At", appDiagnostics.entitledAt)
//                networkDiagnosticsRow("Push Authorization", appDiagnostics.pushAuthorization)
//                networkDiagnosticsRow("iCloud Account", appDiagnostics.iCloudAccount)
//            } header: {
//                Text(verbatim: "Notifications")
//            }
//        }
//    }

    @ViewBuilder
    var device: some View {
        if let report {
            Section {
                networkDiagnosticsRow("Connection", report.connection)
                networkDiagnosticsRow("Local Network", report.localNetworkDenied ? "denied" : "allowed")
                networkDiagnosticsRow("Tailscale", report.tailnetUp ? "up" : "down")
            } header: {
                Text(verbatim: "Network")
            }
        }
    }

    @ViewBuilder
    var network: some View {
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
                Text(verbatim: "Device")
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
                        text: report.exportText(masked: masked, app: appDiagnostics?.exportLines() ?? [])
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

    /// `resolve` (not the passive `currentSelection`) is deliberate: this screen is the one
    /// place that should keep claiming lookups and probes, so the rows it renders converge
    /// while it is open. All the syscall work runs on the resolver actor, off the MainActor.
    func refresh() async {
        let instances = settings.configuredInstances

        for instance in instances {
            _ = await InstanceResolver.shared.resolve(instance)
        }

        let updated = await InstanceResolver.shared.report(for: instances)

        if updated != report {
            report = updated
        }
    }
}

func networkDiagnosticsRow(_ label: String, _ value: String) -> some View {
    networkDiagnosticsRow(label, Text(verbatim: value))
}

func networkDiagnosticsRow(_ label: String, _ valueText: Text) -> some View {
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
