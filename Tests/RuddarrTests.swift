import Testing
import Foundation

@testable import Ruddarr

struct RuddarrTests {
    @Test func resolveLocalizedStringWithArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", "1", "23"]
        let result = String(format: format, arguments: args.map { "\($0)" as NSString })
        #expect(result == "Breaking Bad (S1 E23)")
    }

    @Test func resolveLocalizedStringWithIntArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", 2, 45]
        let result = String(format: format, arguments: args.map { "\($0)" as NSString })
        #expect(result == "Breaking Bad (S2 E45)")
    }

    @Test func resolveLocalizedStringWithNoArgs() {
        let format = "Episode Downloaded"
        let result = String(format: format, arguments: [])
        #expect(result == "Episode Downloaded")
    }

    @Test func resolveLocalizedStringFallback() {
        // When key equals the NSLocalizedString result (key not found), use fallback
        let key = "NONEXISTENT_KEY"
        let format = NSLocalizedString(key, comment: "")
        let fallback = "Fallback Title"

        let result = format == key ? fallback : format
        #expect(result == "Fallback Title")
    }

    @Test func privateIpAddressDetection() {
        // Private ranges
        #expect(isPrivateIpAddress("10.0.0.1") == true)
        #expect(isPrivateIpAddress("10.255.255.255") == true)
        #expect(isPrivateIpAddress("172.16.0.1") == true)
        #expect(isPrivateIpAddress("172.31.255.255") == true)
        #expect(isPrivateIpAddress("192.168.0.1") == true)
        #expect(isPrivateIpAddress("192.168.1.100") == true)
        #expect(isPrivateIpAddress("127.0.0.1") == true)

        // Public ranges
        #expect(isPrivateIpAddress("8.8.8.8") == false)
        #expect(isPrivateIpAddress("182.168.1.1") == false)
        #expect(isPrivateIpAddress("172.32.0.1") == false)
        #expect(isPrivateIpAddress("11.0.0.1") == false)

        // Non-IP strings
        #expect(isPrivateIpAddress("example.com") == false)
        #expect(isPrivateIpAddress("") == false)
    }
}
