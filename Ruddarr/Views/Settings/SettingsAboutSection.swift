import os
import SwiftUI
import Foundation

struct SettingsAboutSection: View {
    private let log: Logger = logger("settings")

    private let shareUrl = URL(string: "https://ruddarr.com")!
    private let githubUrl = URL(string: "https://github.com/ruddarr/app")!
    private let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/????????")!

    var body: some View {
        Section(header: Text("About")) {
            shareLink
            reviewLink
            supportEmail
            github
            libraries
        }
    }

    var shareLink: some View {
        ShareLink(item: shareUrl) {
            Label {
                Text("Share App").tint(.primary)
            } icon: {
                Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
            }
        }
    }

    var reviewLink: some View {
        Link(destination: reviewUrl) {
            Label {
                Text("Leave a Review").tint(.primary)
            } icon: {
                Image(systemName: "star.fill").foregroundColor(.yellow)
            }
        }
    }

    var supportEmail: some View {
        Button {
            Task { await openSupportEmail() }
        } label: {
            Label {
                Text("Email Support").tint(.primary)
            } icon: {
                Image(systemName: "square.and.pencil").foregroundColor(.blue)
            }
        }
    }

    var github: some View {
        Link(destination: githubUrl, label: {
            Label {
                Text("Contribute on GitHub").tint(.primary)
            } icon: {
                Image(systemName: "curlybraces.square").foregroundColor(.purple)
            }
        })
    }

    var libraries: some View {
        NavigationLink { LibrariesView() } label: {
            Label {
                Text("Third Party Libraries").tint(.primary)
            } icon: {
                Image(systemName: "building.columns").foregroundColor(.secondary)
            }
        }
    }

    // If desired add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`
    func openSupportEmail() async {
        let meta = await Telemetry.shared.metadata()

        let uuid = UUID().uuidString.prefix(8)

        let address = "ruddarr@icloud.com"
        let subject = "Support Request (\(uuid))"

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
