import os
import SwiftUI
import Foundation

struct SettingsAboutSection: View {
    private let log: Logger = logger("settings")

    private let shareUrl = URL(string: "https://ruddarr.com")!
    private let githubUrl = URL(string: "https://github.com/ruddarr/app/")!
    private let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/id663592361")!

    var body: some View {
        Section(header: Text("About")) {
            ShareLink(item: shareUrl) {
                Label("Share App", systemImage: "square.and.arrow.up")
            }

            Link(destination: reviewUrl, label: {
                Label("Leave a Review", systemImage: "star")
            })

            Button {
                Task { await openSupportEmail() }
            } label: {
                Label("Email Support", systemImage: "square.and.pencil")
            }

            Link(destination: githubUrl, label: {
                Label("Contribute on GitHub", systemImage: "curlybraces.square")
            })

            NavigationLink { LibrariesView() } label: {
                Label("Third Party Libraries", systemImage: "building.columns")
            }
        }
        .tint(.primary)
    }

    // If desired add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`
    func openSupportEmail() async {
        let meta = await Telemetry.shared.metadata()

        let address = "ruddarr@icloud.com"
        let subject = "Support Request"

        let body = """
        ---
        The following information will help with debugging:

        Version: \(meta[.appVersion] ?? "nil") (\(meta[.appBuild] ?? "nil"))
        Platform: \(meta[.systemName] ?? "nil") (\(meta[.systemVersion] ?? "nil"))
        Device: \(meta[.deviceId] ?? "nil")
        User: \(meta[.cloudkitStatus]!) (\(meta[.cloudkitUserId] ?? "nil"))
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let mailtoUrl = components.url {
            if await UIApplication.shared.canOpenURL(mailtoUrl) {
                if await UIApplication.shared.open(mailtoUrl) {
                    return
                }
            }

            log.warning("Unable to open mailto URL: \(mailtoUrl)")
        }

        let gitHubUrl = URL(string: "https://github.com/ruddarr/app/discussions")!

        if await UIApplication.shared.open(gitHubUrl) {
            return
        }

        log.critical("Unable to open URL: \(gitHubUrl)")
    }
}
