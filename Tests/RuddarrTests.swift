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
        // Mirrors formatCustomScore() in Movie.swift. The "%+d" flag forces a
        // single leading sign, fixing the previous "%@%d" approach that
        // double-signed negatives (e.g. "--5000" instead of "-5000").
        #expect(String(format: "%+d", 500) == "+500")
        #expect(String(format: "%+d", 0) == "+0")
        #expect(String(format: "%+d", -5000) == "-5000")
    }
}
