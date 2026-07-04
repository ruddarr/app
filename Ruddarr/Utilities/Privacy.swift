import Foundation

func maskedURL(_ string: String) -> String {
    guard let components = URLComponents(string: string), let host = components.host else {
        return "•"
    }

    let maskedHost = maskHost(host)
    let hostField = maskedHost.contains(":") ? "[\(maskedHost)]" : maskedHost

    var result = ""
    if let scheme = components.scheme { result += "\(scheme)://" }

    if components.user != nil {
        result += components.password != nil ? "*****:*****@" : "*****@"
    }

    result += hostField
    if let port = components.port { result += ":\(port)" }
    result += components.percentEncodedPath
    if let query = components.percentEncodedQuery { result += "?\(query)" }
    if let fragment = components.percentEncodedFragment { result += "#\(fragment)" }

    return result
}

func maskedIP(_ address: String) -> String {
    maskHost(address)
}

func maskedCIDR(_ cidr: String) -> String {
    let parts = cidr.split(separator: "/", maxSplits: 1)
    guard let address = parts.first else { return cidr }

    let masked = maskHost(String(address))
    return parts.count > 1 ? "\(masked)/\(parts[1])" : masked
}

private func maskHost(_ host: String) -> String {
    let cleaned = NetworkInterfaces.bareHost(host)

    if let v4 = NetworkInterfaces.parseIPv4(cleaned) {
        return maskIPv4(cleaned, v4)
    }

    if let bytes = NetworkInterfaces.parseIPv6(cleaned) {
        return maskIPv6(cleaned, bytes)
    }

    let lower = cleaned.lowercased()
    for suffix in [NetworkInterfaces.tailnetSuffix, NetworkInterfaces.mdnsSuffix] where lower.hasSuffix(suffix) {
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
