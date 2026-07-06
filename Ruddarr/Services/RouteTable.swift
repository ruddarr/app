import Foundation

/// Reads the IPv4 default gateway(s) from the kernel routing table over the `PF_ROUTE` sysctl —
/// the router(s) that forward this device's off-link traffic, shown on the diagnostics screen.
/// `net/route.h` is not part of the iOS SDK, so the few route-message constants and the fixed
/// `rt_msghdr` layout are spelled out here; both are stable Darwin ABI. Parsing is pure over the
/// returned bytes (and unit-tested); only the sysctl read itself touches the kernel.
enum RouteTable {
    /// One IPv4 default route: the gateway address and the interface it routes through.
    struct Gateway: Equatable, Sendable {
        let address: String   // dotted quad, e.g. `192.168.1.1`
        let interface: String // e.g. `en0`
    }

    /// A parsed default-route message: gateway in host order plus the kernel interface index.
    struct Entry: Equatable, Sendable {
        let address: UInt32
        let interfaceIndex: UInt16
    }

    /// The stable Darwin `rt_msghdr` layout: 2-byte message length, version and type bytes,
    /// 2-byte interface index, flags at +8, the sockaddr bitmask at +12, and `rt_metrics`
    /// filling the rest of the 92-byte header. The sockaddrs indicated by the bitmask follow,
    /// each padded to a 4-byte boundary.
    static let headerLength = 92

    private static let rtmVersion: UInt8 = 5    // RTM_VERSION
    private static let netRTFlags: Int32 = 2    // NET_RT_FLAGS
    private static let rtfUp: UInt32 = 0x1      // RTF_UP
    private static let rtfGateway: Int32 = 0x2  // RTF_GATEWAY
    private static let rtaDst: UInt32 = 0x1     // RTA_DST
    private static let rtaGateway: UInt32 = 0x2 // RTA_GATEWAY

    static func defaultGatewaysV4() -> [Gateway] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, netRTFlags, rtfGateway]
        var needed = 0

        guard sysctl(&mib, u_int(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else { return [] }

        var buffer = [UInt8](repeating: 0, count: needed + 1_024) // headroom: the table can grow between the calls
        var size = buffer.count

        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return [] }

        buffer.removeLast(buffer.count - size)

        return parseDefaultGatewaysV4(buffer).map { entry in
            Gateway(
                address: NetworkInterfaces.string(fromIPv4: entry.address),
                interface: interfaceName(entry.interfaceIndex)
            )
        }
    }

    /// Every routing message whose destination is `0.0.0.0` (a default route) contributes its
    /// IPv4 gateway, deduplicated by (gateway, interface) since the kernel lists both scoped and
    /// unscoped copies. Malformed or truncated messages are skipped, never trapped on.
    static func parseDefaultGatewaysV4(_ buffer: [UInt8]) -> [Entry] {
        var entries: [Entry] = []
        var offset = 0

        while offset + headerLength <= buffer.count {
            let length = Int(uint16(buffer, at: offset))
            guard length >= headerLength, offset + length <= buffer.count else { break }
            defer { offset += length }

            guard buffer[offset + 2] == rtmVersion else { continue }
            guard uint32(buffer, at: offset + 8) & rtfUp != 0 else { continue }
            guard let address = defaultGateway(buffer, message: offset, length: length) else { continue }

            let entry = Entry(address: address, interfaceIndex: uint16(buffer, at: offset + 4))

            if !entries.contains(entry) {
                entries.append(entry)
            }
        }

        return entries
    }

    /// The gateway of one route message, or `nil` when the message is not an IPv4 default route
    /// (its destination isn't `0.0.0.0`, or its gateway is a link address rather than an IP).
    private static func defaultGateway(_ buffer: [UInt8], message: Int, length: Int) -> UInt32? {
        let addrs = uint32(buffer, at: message + 12)
        guard addrs & rtaDst != 0, addrs & rtaGateway != 0 else { return nil }

        let end = message + length
        var cursor = message + headerLength

        for bit: UInt32 in 0..<8 where addrs & (1 << bit) != 0 {
            guard cursor + 2 <= end else { return nil }

            let saLen = Int(buffer[cursor])
            let family = buffer[cursor + 1]
            let hasAddress = family == UInt8(AF_INET) && saLen >= 8 && cursor + 8 <= end

            if 1 << bit == rtaDst {
                guard hasAddress, buffer[(cursor + 4)...(cursor + 7)].allSatisfy({ $0 == 0 }) else { return nil }
            }

            if 1 << bit == rtaGateway {
                guard hasAddress else { return nil }

                return UInt32(buffer[cursor + 4]) << 24
                    | UInt32(buffer[cursor + 5]) << 16
                    | UInt32(buffer[cursor + 6]) << 8
                    | UInt32(buffer[cursor + 7])
            }

            cursor += max(4, (saLen + 3) & ~3)
        }

        return nil
    }

    /// The kernel's name for an interface index (`4` → `en0`), or the raw index when the
    /// interface has disappeared since the route was read.
    private static func interfaceName(_ index: UInt16) -> String {
        guard index > 0 else { return "?" }

        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ) + 1)
        guard if_indextoname(UInt32(index), &name) != nil else { return "#\(index)" }

        return String(cString: name)
    }

    // Header fields are host-order in the sysctl buffer; every Apple platform is little-endian.
    private static func uint16(_ buffer: [UInt8], at offset: Int) -> UInt16 {
        UInt16(buffer[offset]) | UInt16(buffer[offset + 1]) << 8
    }

    private static func uint32(_ buffer: [UInt8], at offset: Int) -> UInt32 {
        UInt32(uint16(buffer, at: offset)) | UInt32(uint16(buffer, at: offset + 2)) << 16
    }
}
