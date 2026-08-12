import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

extension DiagnosticsView {
    var exportFilename: String {
        networkDiagnosticsExportURL.deletingPathExtension().lastPathComponent
    }
}

let networkDiagnosticsExportURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ruddarr-diagnostics.txt")

struct NetworkDiagnosticsExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { export in
            try export.text.write(to: networkDiagnosticsExportURL, atomically: true, encoding: .utf8)

            return SentTransferredFile(networkDiagnosticsExportURL)
        }
    }
}

struct NetworkDiagnosticsHighlighter {
    let subnets: [IPv4Subnet]

    func address(_ shown: String, highlightMismatch: Bool) -> Text {
        Text(attributedAddress(shown, highlightMismatch: highlightMismatch))
    }

    func addressList(_ shown: [String], highlightMismatch: Bool) -> Text {
        guard !shown.isEmpty else { return Text(verbatim: "none") }

        var result = AttributedString()
        for (index, value) in shown.enumerated() {
            if index > 0 { result += AttributedString(", ") }
            result += attributedAddress(value, highlightMismatch: highlightMismatch)
        }

        return Text(result)
    }

    func attributedAddress(_ shown: String, highlightMismatch: Bool) -> AttributedString {
        guard let octets = ipv4Octets(shown), let subnet = referenceSubnet(for: octets) else {
            return AttributedString(shown)
        }

        let parts = shown.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 { result += AttributedString(".") }
            var piece = AttributedString(part)
            if let color = octetColor(index: index, octet: octets[index], subnet: subnet, highlightMismatch: highlightMismatch) {
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
        guard !subnets.isEmpty else { return nil }

        return subnets.max { $0.commonNetworkOctets(with: octets) < $1.commonNetworkOctets(with: octets) }
    }

    func octetColor(index: Int, octet: UInt8?, subnet: IPv4Subnet, highlightMismatch: Bool) -> Color? {
        switch subnet.networkOctetMatches(octet, at: index) {
        case .some(true): return .green
        case .some(false): return highlightMismatch ? .orange : nil
        case .none: return nil
        }
    }
}
