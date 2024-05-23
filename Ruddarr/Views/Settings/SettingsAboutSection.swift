import os
import SwiftUI
import CloudKit
import Foundation

struct SettingsAboutSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openURL) var openURL

    var body: some View {
        Section(header: Text("About")) {
            share
            review
            support
        }
    }

    var share: some View {
        ShareLink(item: Links.AppShare) {
            Label {
                Text("Share App").tint(.primary)
            } icon: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    var review: some View {
        Link(destination: Links.AppStore.appending(queryItems: [
            .init(name: "action", value: "write-review"),
        ])) {
            Label {
                Text("Leave a Review").tint(.primary)
            } icon: {
                Image(systemName: "star")
                    .symbolVariant(.fill)
                    .foregroundStyle(settings.theme.tint)
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
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    @MainActor
    func openSupportEmail() async {
        let uuid = UUID().uuidString.prefix(8)
        let deviceId = Platform.deviceId()

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
        Account: \(ckStatus) (\(cloudKitUserId ?? "unknown"))
        Device: \(deviceId)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n\(body)")
        ]

        let openFallbackUrl = { () in
            openURL(Links.GitHubDiscussions) { opened in
                if !opened {
                    leaveBreadcrumb(.warning, category: "settings.about", message: "Unable to open GitHub Discussions")
                }
            }
        }

        if let mailtoUrl = components.url {
            openURL(mailtoUrl) { opened in
                if !opened {
                    leaveBreadcrumb(.warning, category: "settings.about", message: "Unable to open mailto", data: ["url": mailtoUrl])
                    openFallbackUrl()
                }
            }
        } else {
            openFallbackUrl()
        }
    }

    var systemName: String {
        #if os(macOS)
            return "macOS"
        #else
            UIDevice.current.systemName
        #endif
    }

    var systemVersion: String {
        #if os(macOS)
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
            UIDevice.current.systemVersion
        #endif
    }

    var appVersion: String {
        if let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String {
            return appVersion
        }

        return String(localized: "Unknown")
    }

    var appBuild: String {
        if let buildNumber = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String {
            return buildNumber
        }

        return String(localized: "Unknown")
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
