import SwiftUI

struct NoInstance: View {
    let type: String

    var body: some View {
        let description = String(
            format: String(localized: "Connect a %@ instance under %@."),
            type,
            String(format: "[%@](#view)", String(localized: "Settings"))
        )

        return ContentUnavailableView(
            "No \(type) Instance",
            systemImage: "externaldrive.badge.xmark",
            description: Text(description.toMarkdown())
        ).environment(\.openURL, .init { _ in
            dependencies.router.selectedTab = .settings
            return .handled
        })
    }
}
