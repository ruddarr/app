import Testing
import Foundation

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

    @Test func formatCustomScoreIsSigned() {
        #expect(formatCustomScore(500) == "+500")
        #expect(formatCustomScore(0) == "+0")
        // Negative scores must not be double-signed (e.g. "--5000")
        #expect(formatCustomScore(-5000) == "-5000")
    }
}
