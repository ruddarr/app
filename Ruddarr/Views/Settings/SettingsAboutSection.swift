import os
import SwiftUI
import CloudKit
import CryptoKit
import Foundation

struct SettingsAboutSection: View {
    private let log: Logger = logger("settings")

    private let shareUrl = URL(string: "https://ruddarr.com")!
    private let githubUrl = URL(string: "https://github.com/ruddarr/app")!
    private let reviewUrl = URL(string: "itms-apps://itunes.apple.com/app/????????")!

    var body: some View {
        Section(header: Text("About")) {
            share
            review
            support
            contribute
            invite
            libraries
        }
    }

    var share: some View {
        ShareLink(item: shareUrl) {
            Label {
                Text("Share App").tint(.primary)
            } icon: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.blue)
            }
        }
    }

    var review: some View {
        Link(destination: reviewUrl) {
            Label {
                Text("Leave a Review").tint(.primary)
            } icon: {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
        }
    }

    var support: some View {
        Button {
            Task { await openSupportEmail() }
        } label: {
            Label {
                Text("Email Support").tint(.primary)
            } icon: {
                Image(systemName: "square.and.pencil").foregroundStyle(.blue)
            }
        }
    }

    var contribute: some View {
        Link(destination: githubUrl, label: {
            Label {
                Text("Contribute on GitHub").tint(.primary)
            } icon: {
                Image(systemName: "curlybraces.square").foregroundStyle(.purple)
            }
        })
    }

    var invite: some View {
        Button {
            Task { await openInviteEmail() }
        } label: {
            Label {
                Text("Invite me to BTN / PTP").tint(.primary)
            } icon: {
                Image(systemName: "figure.2").foregroundStyle(.orange).scaleEffect(0.9)
            }
        }
    }

    var libraries: some View {
        NavigationLink { LibrariesView() } label: {
            Label {
                Text("Third Party Libraries").tint(.primary)
            } icon: {
                Image(systemName: "text.book.closed").foregroundStyle(.blue)
            }
        }
    }

    // If desired add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`
    func openSupportEmail() async {
        let uuid = UUID().uuidString.prefix(8)

        let cloudKitStatus = try? await CKContainer.default().accountStatus()
        let cloudKitUserId = try? await CKContainer.default().userRecordID().recordName
        let ckStatus = Telemetry.shared.cloudKitStatus(cloudKitStatus)

        let address = "ruddarr@icloud.com"
        let subject = "Support Request (\(uuid))"

        let body = """
        ---
        The following information will help with debugging:

        Version: \(appVersion) (\(appBuild))
        Platform: \(systemName) (\(systemVersion))
        User: \(ckStatus) (\(cloudKitUserId ?? "unknown"))
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

    func openInviteEmail() async {
        let address = "ruddarr@icloud.com"
        let subject = "Invite"

        let body = "I have an invite for you, let's talk."

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
        }
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
