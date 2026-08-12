import Foundation

struct Links {
    static let AppShare = URL(string: "https://apps.apple.com/app/ruddarr/id6476240130")!
    static let AppStore = URL(string: "itms-apps://itunes.apple.com/app/id6476240130")!
    static let TestFlight = URL(string: "https://testflight.apple.com/join/N2YE9J9A")!
    static let Discord = URL(string: "https://discord.gg/UksvtDQUBA")!
    static let Crowdin = URL(string: "https://crowdin.com/project/ruddarr")!
    static let GitHub = URL(string: "https://github.com/ruddarr/app")!
    static let GitHubIssues = URL(string: "https://github.com/ruddarr/app/issues")!
    static let GitHubReleases = URL(string: "https://github.com/ruddarr/app/releases")!
}

struct Secrets {
    static let SentryDsn: String = "https://47df7eb41059b96d7f10733d28442d3d@o4506759093354496.ingest.sentry.io/4506759167803392"
    static let TelemetryAppId: String = "5B1D07EE-E296-4DCF-B3DD-150EDE9D56B5"
}
