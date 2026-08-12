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
    if let query = components.percentEncodedQuery { result += "?\(maskedQueryValues(query))" }
    if let fragment = components.percentEncodedFragment { result += "#\(fragment)" }

    return result
}

/// Query parameter names whose values carry user-identifying data or credentials — search text,
/// download identifiers, and the query-string API keys of Newznab/Torznab-style URLs that server
/// error messages can embed. Only these are redacted from a masked URL; everything else is kept
/// so a shared diagnostics report still shows the failing endpoint and its non-sensitive parameters.
private let sensitiveQueryKeys: Set<String> = ["term", "downloadid", "apikey", "api_key"]

private func maskedQueryValues(_ query: String) -> String {
    query.split(separator: "&", omittingEmptySubsequences: false).map { pair in
        guard let separator = pair.firstIndex(of: "="),
              sensitiveQueryKeys.contains(pair[..<separator].lowercased())
        else { return String(pair) }

        return "\(pair[..<separator])=•"
    }.joined(separator: "&")
}

func maskURLs(in string: String) -> String {
    string.replacing(/https?:\/\/[^\s"'<>)\]};,]+/) { match in
        maskedURL(String(match.output))
    }
}

/// A URL with any inline `user:password@` credentials replaced by `*****`, but scheme, host,
/// port, path and query shown verbatim — for the unmasked diagnostics export, where revealing
/// network topology must never reveal stored passwords. Returns the input unchanged when it
/// carries no credentials (or can't be parsed), so ordinary URLs stay byte-for-byte intact.
func urlHidingUserinfo(_ string: String) -> String {
    guard let components = URLComponents(string: string),
          let host = components.host,
          components.user != nil
    else { return string }

    let hostField = host.contains(":") ? "[\(host)]" : host

    var result = ""
    if let scheme = components.scheme { result += "\(scheme)://" }
    result += components.password != nil ? "*****:*****@" : "*****@"
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

    if NetworkInterfaces.isPrivateV4(ip) {
        return "\(octets[0]).\(octets[1]).\(octets[2]).*"
    }

    return "\(octets[0]).\(octets[1]).*.*"
}

private func maskIPv6(_ host: String, _ bytes: [UInt8]) -> String {
    if NetworkInterfaces.isLoopbackV6(bytes: bytes) { return host }
    if NetworkInterfaces.isTailscaleULA(bytes: bytes) { return "fd7a:115c:a1e0::*" }

    let first = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? host
    return "\(first)::*"
}
