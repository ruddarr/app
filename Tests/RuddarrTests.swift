import Testing
import Foundation

// Replicates the resolveLocalizedString logic from NotificationService
private func formatLocalized(_ format: String, args: [Any]) -> String {
    let stringArgs = args.map { String(describing: $0) }

    switch stringArgs.count {
    case 1: return String(format: format, stringArgs[0])
    case 2: return String(format: format, stringArgs[0], stringArgs[1])
    case 3: return String(format: format, stringArgs[0], stringArgs[1], stringArgs[2])
    case 4: return String(format: format, stringArgs[0], stringArgs[1], stringArgs[2], stringArgs[3])
    case 5: return String(format: format, stringArgs[0], stringArgs[1], stringArgs[2], stringArgs[3], stringArgs[4])
    default: return format
    }
}

struct RuddarrTests {
    @Test func resolveLocalizedStringWithArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", "1", "23"]
        let result = formatLocalized(format, args: args)
        #expect(result == "Breaking Bad (S1 E23)")
    }

    @Test func resolveLocalizedStringWithIntArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", 2, 45]
        let result = formatLocalized(format, args: args)
        #expect(result == "Breaking Bad (S2 E45)")
    }

    @Test func resolveLocalizedStringWithMixedArgs() {
        let format = "%@ (%@)"
        let args: [Any] = ["The Super Mario Bros. Movie", 2023]
        let result = formatLocalized(format, args: args)
        #expect(result == "The Super Mario Bros. Movie (2023)")
    }

    @Test func resolveLocalizedStringWithPositionalArgs() {
        let format = "%2$@ Episodes Downloaded on %1$@"
        let args: [Any] = ["Sonarr", 5]
        let result = formatLocalized(format, args: args)
        #expect(result == "5 Episodes Downloaded on Sonarr")
    }

    @Test func resolveLocalizedStringWithPositionalIntArgs() {
        let format = "Upgraded from %1$@ to %2$@"
        let args: [Any] = ["HDTV-720p", "Bluray-1080p"]
        let result = formatLocalized(format, args: args)
        #expect(result == "Upgraded from HDTV-720p to Bluray-1080p")
    }

    @Test func resolveLocalizedStringWithNoArgs() {
        let format = "Episode Downloaded"
        let result = formatLocalized(format, args: [])
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
}
