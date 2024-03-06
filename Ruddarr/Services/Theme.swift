import SwiftUI

// https://developer.apple.com/design/human-interface-guidelines/color
enum Theme: String, Identifiable, CaseIterable {
    static let factory = Theme.purple

    case blue
    case purple
    case green
    case pink
    case red
    case orange
    case yellow
    case mono
    // cyan (Translate)

    var id: Self { self }

    var label: String {
        switch self {
        case .blue: "Mail"
        case .purple: "Podcasts"
        case .green: "Fitness"
        case .pink: "Music"
        case .red: "Music"
        case .orange: "Watch"
        case .yellow: "Notes"
        case .mono: "Books"
        }
    }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .purple: Color.purple
        case .green: Color("Fitness")
        case .pink: Color.pink
        case .red: Color.red
        case .orange: Color.orange
        case .yellow: Color.yellow
        case .mono: Color("Monochrome")
        }
    }

    var toggleTint: Color {
        switch self {
        case .mono: Color.green
        default: tint
        }
    }
}

enum Appearance: String, Identifiable, CaseIterable {
    case automatic
    case light
    case dark

    var id: Self { self }

    var label: String {
        self.rawValue.capitalized
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppIcon: String, Identifiable, CaseIterable {
    case factory
    case red
    case purple
    case mono

    var id: Self { self }

    var data: AppIconData {
        switch self {
        case .factory: AppIconData.factory
        case .red: AppIconData.red
        case .purple: AppIconData.purple
        case .mono: AppIconData.mono
        }
    }
}

struct AppIconData {
    var label: String
    var asset: String
    var locked: Bool

    var value: String? {
        asset == "AppIcon" ? nil : asset
    }

    var uiImage: UIImage {
        guard let image = UIImage(named: asset) else {
            assertionFailure("Missing asset: \(asset)")

            return UIImage()
        }

        return image
    }

    static var factory: Self {
        .init(label: "Default", asset: "AppIcon", locked: false)
    }

    static var purple: Self {
        .init(label: "Podcasts", asset: "AppIconPurple", locked: false)
    }

    static var red: Self {
        .init(label: "Music", asset: "AppIconRed", locked: false)
    }

    static var mono: Self {
        .init(label: "Monochrome", asset: "AppIconMono", locked: true)
    }
}
