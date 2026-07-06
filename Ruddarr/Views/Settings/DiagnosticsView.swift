import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var report: NetworkReport?
    @State private var masked: Bool = true
    @State private var collapsedInstances: Set<Instance.ID> = []
    @State private var expandedCandidates: Set<String> = []

    var body: some View {
        List {
            if let report {
                deviceSection(report)

                ForEach(report.instances) { entry in
                    instanceSection(entry)
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.snappy, value: masked)
        .toolbar {
            toolbarMaskButton
            toolbarShareButton
        }
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    var mask: NetworkDiagnosticsMask {
        NetworkDiagnosticsMask(masked: masked)
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
        }
    }

    @ToolbarContentBuilder
    var toolbarShareButton: some ToolbarContent {
        if let report {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: NetworkDiagnosticsExport(text: report.exportText(masked: masked)),
                    preview: SharePreview(exportFilename)
                )
            }
        }
    }

    func deviceSection(_ report: NetworkReport) -> some View {
        Section {
            networkDiagnosticsRow("Local Network", report.localNetworkDenied ? "denied" : "allowed")
            networkDiagnosticsRow("Tailscale", report.tailnetUp ? "up" : "down")
            networkDiagnosticsRow("IPv4 Address", mask.list(report.deviceV4.map { mask.ip(NetworkInterfaces.string(fromIPv4: $0.address)) }))
            networkDiagnosticsRow("IPv4 Subnets", mask.list(report.lanV4.map(mask.cidr)))
            networkDiagnosticsRow("IPv6 Address", mask.list(report.deviceV6.map { mask.ip(NetworkInterfaces.string(fromIPv6Bytes: $0.address)) }))
            networkDiagnosticsRow("IPv6 Subnets", mask.list(report.lanV6.map(mask.cidr)))
        } header: {
            Text(verbatim: "Device")
        }
    }

    func instanceSection(_ entry: NetworkReport.InstanceEntry) -> some View {
        Section(isExpanded: expansion(for: entry.id)) {
            networkDiagnosticsRow("Type", entry.type)

            ForEach(entry.candidates) { candidate in
                candidateDisclosure(candidate, instanceID: entry.id)
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

    func candidateDisclosure(_ candidate: NetworkReport.Candidate, instanceID: Instance.ID) -> some View {
        DisclosureGroup(isExpanded: candidateExpansion(for: "\(instanceID)|\(candidate.url)")) {
            networkDiagnosticsRow("Host", candidateHostText(candidate))
            networkDiagnosticsRow("Position", candidate.primary ? "primary" : "alternate")
            networkDiagnosticsRow("Role", candidate.roleDescription)
            networkDiagnosticsRow("On-Link", onLinkText(candidate))
            networkDiagnosticsRow("Score", "\(candidate.score)")
            if candidate.hasHostname {
                networkDiagnosticsRow("Resolved IPs", candidateAddressesText(candidate))
            }
        } label: {
            candidateHeader(candidate)
        }
    }

    func candidateHeader(_ candidate: NetworkReport.Candidate) -> some View {
        HStack(spacing: 5) {
            Text(verbatim: mask.url(candidate.url))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .contentTransition(.opacity)

            Image(systemName: candidate.selected ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(candidate.selected ? AnyShapeStyle(settings.theme.tint) : AnyShapeStyle(.tertiary))
        }
    }

    func candidateHostText(_ candidate: NetworkReport.Candidate) -> Text {
        let shown = mask.host(of: candidate.url)
        return candidate.role == .lan ? coloredAddress(shown) : Text(verbatim: shown)
    }

    func candidateAddressesText(_ candidate: NetworkReport.Candidate) -> Text {
        let shown = candidate.addresses.map(mask.ip)
        guard candidate.role == .lan else {
            return Text(verbatim: shown.isEmpty ? "none" : shown.joined(separator: ", "))
        }
        return coloredAddressList(shown)
    }

    func onLinkText(_ candidate: NetworkReport.Candidate) -> Text {
        var value = AttributedString(candidate.onLink ? "yes" : "no")
        if candidate.onLink {
            value.foregroundColor = .green
        } else if candidate.role == .lan {
            value.foregroundColor = .orange
        }
        return Text(value)
    }

    func coloredAddress(_ shown: String) -> Text {
        Text(attributedIPv4(shown))
    }

    func coloredAddressList(_ shown: [String]) -> Text {
        guard !shown.isEmpty else { return Text(verbatim: "none") }

        var result = AttributedString()
        for (index, value) in shown.enumerated() {
            if index > 0 { result += AttributedString(", ") }
            result += attributedIPv4(value)
        }

        return Text(result)
    }

    func attributedIPv4(_ shown: String) -> AttributedString {
        guard let octets = ipv4Octets(shown), let subnet = referenceSubnet(for: octets) else {
            return AttributedString(shown)
        }

        let parts = shown.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 { result += AttributedString(".") }
            var piece = AttributedString(part)
            if let color = octetColor(index: index, octet: octets[index], subnet: subnet) {
                piece.foregroundColor = color
            }
            result += piece
        }

        return result
    }

    func ipv4Octets(_ shown: String) -> [UInt8?]? {
        let parts = shown.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }

        var octets: [UInt8?] = []
        for part in parts {
            if part == "*" {
                octets.append(nil)
            } else if let value = UInt8(part) {
                octets.append(value)
            } else {
                return nil
            }
        }

        return octets
    }

    func referenceSubnet(for octets: [UInt8?]) -> IPv4Subnet? {
        let subnets = report?.deviceV4 ?? []
        guard !subnets.isEmpty else { return nil }

        return subnets.max { commonNetworkOctets(octets, $0) < commonNetworkOctets(octets, $1) }
    }

    func commonNetworkOctets(_ octets: [UInt8?], _ subnet: IPv4Subnet) -> Int {
        var count = 0
        for index in 0..<4 {
            guard octetMatch(index: index, octet: octets[index], subnet: subnet) == true else { break }
            count += 1
        }
        return count
    }

    func octetMatch(index: Int, octet: UInt8?, subnet: IPv4Subnet) -> Bool? {
        let shift = 24 - 8 * index
        let maskByte = UInt8((subnet.mask >> shift) & 0xFF)
        guard maskByte != 0, let octet else { return nil }

        let networkByte = UInt8(((subnet.address & subnet.mask) >> shift) & 0xFF)
        return (octet & maskByte) == (networkByte & maskByte)
    }

    func octetColor(index: Int, octet: UInt8?, subnet: IPv4Subnet) -> Color? {
        switch octetMatch(index: index, octet: octet, subnet: subnet) {
        case .some(true): return .green
        case .some(false): return .orange
        case .none: return nil
        }
    }

    func refresh() {
        let instances = settings.configuredInstances

        for instance in instances {
            _ = InstanceResolver.shared.currentSelection(for: instance)
        }

        let updated = InstanceResolver.shared.report(for: instances)

        if updated != report {
            report = updated
        }
    }

    var exportFilename: String {
        "ruddarr-network-diagnostics"
    }
}

func networkDiagnosticsRow(_ label: String, _ value: String) -> some View {
    networkDiagnosticsRow(label, Text(verbatim: value))
}

func networkDiagnosticsRow(_ label: String, _ valueText: Text) -> some View {
    LabeledContent {
        valueText
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
            .contentTransition(.opacity)
    } label: {
        Text(verbatim: label)
    }
}

struct NetworkDiagnosticsExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { export in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ruddarr-diagnostics.txt")

            try export.text.write(to: url, atomically: true, encoding: .utf8)

            return SentTransferredFile(url)
        }
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
