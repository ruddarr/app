import SwiftUI

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
                appDiagnostics = await AppDiagnostics.load()

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

    var model: DiagnosticsReport {
        DiagnosticsReport(report: report, app: appDiagnostics, requests: failedRequests)
    }

    @ViewBuilder
    var content: some View {
        let model = model

        Section {
            Toggle(isOn: $elevator) {
                Text(verbatim: "Elevator Music")
            }
        } header: {
            Text(verbatim: "App")
        }

        ForEach(model.sections) { section in
            diagnosticSection(section)
        }

        ForEach(model.instances) { entry in
            instanceSection(entry)
        }

        requestsSection(model.failedRequests)
    }

    @ViewBuilder
    func diagnosticSection(_ section: DiagnosticSection) -> some View {
        let rows = section.screenRows

        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    networkDiagnosticsRow(row.label, row.value.string(masked: masked))
                }
            } header: {
                Text(verbatim: section.title)
            }
        }
    }

    @ViewBuilder
    func requestsSection(_ requests: [FailedRequest]) -> some View {
        if !requests.isEmpty {
            Section {
                ForEach(requests) { request in
                    requestRow(request)
                }
            } header: {
                Text(verbatim: "Failed Requests")
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
        if report != nil {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: NetworkDiagnosticsExport(
                        text: DiagnosticsExport.text(from: model, masked: masked)
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
                        networkDiagnosticsRow("Probe", outcomeText(candidate.probeDescription, reachable: candidate.probe?.reachable == true))
                    }

                    if candidate.webDescription != nil {
                        networkDiagnosticsRow("Web", outcomeText(candidate.webDescription, reachable: candidate.web?.reachable == true))
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

    func outcomeText(_ description: String?, reachable: Bool) -> Text {
        var value = AttributedString(description ?? "")
        value.foregroundColor = reachable ? .green : .orange

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

        // Fire-and-forget: verdicts land in the resolver's cache and the next two-second tick
        // renders them, so a dead host's timeout can never stall this refresh loop.
        for instance in instances {
            Task { _ = await InstanceResolver.shared.reachableWebURL(for: instance) }
        }
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
                Text(verbatim: mask.text(detail, for: request.url))
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

    #if DEBUG
    Task { await RequestDiagnostics.shared.seed(FailedRequest.previews) }
    #endif

    return ContentView().withAppState()
}
