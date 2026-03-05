import Testing
import Foundation

struct RuddarrTests {
    @Test func resolveLocalizationsWithIntArgs() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title-loc-args": ["Sonarr"],
                    "subtitle-loc-args": ["Breaking Bad", "1", "23"],
                    "loc-args": ["Breaking Bad", 2, 45],
                ] as [String: Any],
            ] as [String: Any],
        ]

        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]

        if let args = alert?["title-loc-args"] as? [Any] {
            let result = String(format: "Episode Downloaded on %@", arguments: args.map { "\($0)" as NSString })
            #expect(result == "Episode Downloaded on Sonarr")
        }

        if let args = alert?["subtitle-loc-args"] as? [Any] {
            let result = String(format: "%@ (S%@ E%@)", arguments: args.map { "\($0)" as NSString })
            #expect(result == "Breaking Bad (S1 E23)")
        }

        if let args = alert?["loc-args"] as? [Any] {
            let result = String(format: "%@ (S%@ E%@)", arguments: args.map { "\($0)" as NSString })
            #expect(result == "Breaking Bad (S2 E45)")
        }
    }
}
