import Network
import Foundation

func maskedURL(_ string: String) -> String {
    guard let components = URLComponents(string: string), let host = components.host else {
        return "•"
    }

    let masked = maskHost(host)
    let replacement = masked.contains(":") ? "[\(masked)]" : masked
    let original = string.contains("[\(host)]") ? "[\(host)]" : host

    guard let range = string.range(of: original) else { return "•" }
    return string.replacingCharacters(in: range, with: replacement)
}

private func maskHost(_ host: String) -> String {
    let bare = host
        .replacingOccurrences(of: "[", with: "")
        .replacingOccurrences(of: "]", with: "")
    let cleaned = bare.hasSuffix(".") ? String(bare.dropLast()) : bare

    if let v4 = NetworkInterfaces.parseIPv4(cleaned) {
        return maskIPv4(cleaned, v4)
    }

    if let raw = IPv6Address(cleaned)?.rawValue, raw.count == 16 {
        return maskIPv6(cleaned, [UInt8](raw))
    }

    let lower = cleaned.lowercased()
    for suffix in [".ts.net", ".local"] where lower.hasSuffix(suffix) {
        return maskLabels(String(cleaned.dropLast(suffix.count)), keepingTLD: false) + suffix
    }

    return maskLabels(cleaned, keepingTLD: true)
}

private func maskLabels(_ host: String, keepingTLD: Bool) -> String {
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    let tldIndex = (keepingTLD && labels.count > 1) ? labels.count - 1 : -1

    return labels.enumerated()
        .map { index, label in index == tldIndex ? String(label) : maskLabel(label) }
        .joined(separator: ".")
}

private func maskLabel(_ label: Substring) -> String {
    guard label.count > 1 else { return String(label) }

    let keep = (label.count + 1) / 2
    return String(label.prefix(keep)) + String(repeating: "*", count: label.count - keep)
}

private func maskIPv4(_ host: String, _ ip: UInt32) -> String {
    if NetworkInterfaces.isLoopbackV4(ip) { return host }

    let octets = host.split(separator: ".")
    guard octets.count == 4 else { return host }
    return "\(octets[0]).\(octets[1]).*.*"
}

private func maskIPv6(_ host: String, _ bytes: [UInt8]) -> String {
    if NetworkInterfaces.isLoopbackV6(bytes: bytes) { return host }
    if NetworkInterfaces.isTailscaleULA(bytes: bytes) { return "fd7a:115c:a1e0::*" }

    let first = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? host
    return "\(first)::*"
}
