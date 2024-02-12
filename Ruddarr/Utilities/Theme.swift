import SwiftUI

// https://developer.apple.com/design/human-interface-guidelines/color
enum Theme: String, Identifiable, CaseIterable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green" // get closer to neon-green like Fitness?
    case pink = "Pink" // get closer to news color?
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case mono = "Monochrome"

    static let factory = Theme.purple

    var id: Self { self }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .purple: Color.purple
        case .green: Color.green
        case .pink: Color.pink
        case .red: Color.red
        case .orange: Color.orange
        case .yellow: Color.yellow
        case .mono: Color("Mono")
        }
    }
}

enum Appearance: String, Identifiable, CaseIterable {
    case automatic
    case light
    case dark

    var id: Self { self }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
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
    case mono

    var id: Self { self }

    var data: AppIconData {
        switch self {
        case .factory: AppIconData.factory
        case .red: AppIconData.red
        case .mono: AppIconData.mono
        }
    }
}

struct AppIconData {
    var label: String
    var asset: String

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
        .init(label: "Default", asset: "AppIcon")
    }

    static var red: Self {
        .init(label: "Red", asset: "AppIconRed")
    }

    static var mono: Self {
        .init(label: "Monochrome", asset: "AppIconMono")
    }
}
