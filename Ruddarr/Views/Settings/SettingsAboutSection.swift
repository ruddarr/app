import os
import SwiftUI
import Foundation
import CryptoKit

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
        let uuid = UUID().uuidString.prefix(8)

        let address = "ruddarr@icloud.com"
        let subject = "Support Request (\(uuid))"

        let body = """
        ---
        The following information will help with debugging:

        Version: \(appVersion) (\(appBuild))
        Platform: \(systemName) (\(systemVersion))
        Device: \(deviceId)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n\(body)")
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

    var systemName: String {
        UIDevice.current.systemName
    }

    var systemVersion: String {
        UIDevice.current.systemVersion
    }

    var appVersion: String {
        if let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String {
            return appVersion
        }

        return "Unknown"
    }

    var appBuild: String {
        if let buildNumber = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String {
            return buildNumber
        }

        return "Unknown"
    }

    var deviceId: String {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            return "Unknown"
        }

        return SHA256
            .hash(data: deviceId.data(using: .utf8)!)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
