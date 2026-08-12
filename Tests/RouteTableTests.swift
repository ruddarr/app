import Testing
import Foundation

// Validates the pure `PF_ROUTE` message parsing in Ruddarr/Services/RouteTable.swift against
// hand-built routing messages: the fixed `rt_msghdr` layout, the 4-byte sockaddr rounding, and
// the failure modes a kernel buffer can present — non-default destinations, link-layer gateways,
// down routes, unknown message versions, duplicates and truncation.
struct RouteTableTests {
    private func ipv4(_ string: String) -> UInt32 {
        NetworkInterfaces.parseIPv4(string)!
    }

    private func sockaddrIn(_ address: String) -> [UInt8] {
        let value = ipv4(address)
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 16
        bytes[1] = UInt8(AF_INET)
        bytes[4] = UInt8((value >> 24) & 0xFF)
        bytes[5] = UInt8((value >> 16) & 0xFF)
        bytes[6] = UInt8((value >> 8) & 0xFF)
        bytes[7] = UInt8(value & 0xFF)
        return bytes
    }

    private func sockaddrLink() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 20
        bytes[1] = UInt8(AF_LINK)
        return bytes
    }

    private func message(
        destination: [UInt8],
        gateway: [UInt8],
        flags: UInt32 = 0x3, // RTF_UP | RTF_GATEWAY
        index: UInt16 = 4,
        version: UInt8 = 5
    ) -> [UInt8] {
        var payload: [UInt8] = []
        for sockaddr in [destination, gateway] {
            let advance = max(4, (sockaddr.count + 3) & ~3)
            payload += sockaddr + [UInt8](repeating: 0, count: advance - sockaddr.count)
        }

        var header = [UInt8](repeating: 0, count: RouteTable.headerLength)
        let total = header.count + payload.count
        header[0] = UInt8(total & 0xFF)
        header[1] = UInt8((total >> 8) & 0xFF)
        header[2] = version
        header[3] = 4 // RTM_GET
        header[4] = UInt8(index & 0xFF)
        header[5] = UInt8((index >> 8) & 0xFF)
        header[8] = UInt8(flags & 0xFF)
        header[9] = UInt8((flags >> 8) & 0xFF)
        header[10] = UInt8((flags >> 16) & 0xFF)
        header[11] = UInt8((flags >> 24) & 0xFF)
        header[12] = 0x3 // RTA_DST | RTA_GATEWAY
        return header + payload
    }

    @Test func findsDefaultGateway() {
        let buffer = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"), index: 7)

        #expect(RouteTable.parseDefaultGatewaysV4(buffer) == [
            RouteTable.Entry(address: ipv4("192.168.1.1"), interfaceIndex: 7)
        ])
    }

    @Test func skipsNonDefaultDestinations() {
        let buffer = message(destination: sockaddrIn("192.168.5.0"), gateway: sockaddrIn("192.168.1.1"))

        #expect(RouteTable.parseDefaultGatewaysV4(buffer).isEmpty)
    }

    @Test func skipsLinkLayerGateways() {
        let buffer = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrLink())

        #expect(RouteTable.parseDefaultGatewaysV4(buffer).isEmpty)
    }

    @Test func skipsRoutesThatAreDown() {
        let buffer = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"), flags: 0x2)

        #expect(RouteTable.parseDefaultGatewaysV4(buffer).isEmpty)
    }

    @Test func skipsUnknownVersionsButKeepsParsing() {
        let buffer = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("10.0.0.1"), version: 4)
            + message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"), index: 9)

        #expect(RouteTable.parseDefaultGatewaysV4(buffer) == [
            RouteTable.Entry(address: ipv4("192.168.1.1"), interfaceIndex: 9)
        ])
    }

    @Test func dedupesScopedAndUnscopedCopies() {
        let route = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"))

        #expect(RouteTable.parseDefaultGatewaysV4(route + route).count == 1)
    }

    @Test func keepsDistinctGatewaysAndInterfaces() {
        let buffer = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"), index: 4)
            + message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("10.0.20.1"), index: 12)

        #expect(RouteTable.parseDefaultGatewaysV4(buffer) == [
            RouteTable.Entry(address: ipv4("192.168.1.1"), interfaceIndex: 4),
            RouteTable.Entry(address: ipv4("10.0.20.1"), interfaceIndex: 12),
        ])
    }

    @Test func ignoresTruncatedBuffers() {
        let valid = message(destination: sockaddrIn("0.0.0.0"), gateway: sockaddrIn("192.168.1.1"))

        #expect(RouteTable.parseDefaultGatewaysV4(Array(valid.prefix(valid.count - 8))).isEmpty)
        #expect(RouteTable.parseDefaultGatewaysV4(Array(valid.prefix(50))).isEmpty)
        #expect(RouteTable.parseDefaultGatewaysV4([]).isEmpty)
    }

    // The live sysctl read: contents depend on the host, so this only exercises the code path.
    @Test func liveReadDoesNotTrap() {
        _ = RouteTable.defaultGatewaysV4()
    }
}
