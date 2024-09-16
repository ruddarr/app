import SwiftUI

struct NoInstance: View {
    let type: String?

    init(type: String? = nil) {
        self.type = type
    }

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "externaldrive.badge.xmark",
            description: Text(description.toMarkdown())
        ).environment(\.openURL, .init { _ in
            dependencies.router.selectedTab = .settings
            return .handled
        })
    }

    var title: LocalizedStringKey {
        guard let type else {
            return "No Instance"
        }

        return "No \(type) Instance"
    }

    var description: String {
        let fallback = ["Radarr", "Sonarr"].formatted(.list(type: .or))

        return String(
            format: String(localized: "Connect a %@ instance under %@."),
            type == nil ? fallback : type!,
            String(format: "[%@](#view)", String(localized: "Settings"))
        )
    }
}
