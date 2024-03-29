import SwiftUI

// https://developer.apple.com/design/human-interface-guidelines/color
enum Theme: String, Identifiable, CaseIterable {
    static let factory = Theme.purple

    case blue
    case purple
    case green
    case red
    case orange
    case yellow
    case mono
    case brown
    case barbie
    // cyan (Translate)

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .blue: "Mail"
        case .purple: "Podcasts"
        case .green: "Fitness"
        case .red: "Music"
        case .orange: "Watch"
        case .yellow: "Notes"
        case .mono: "Books"
        case .barbie: "Barbie"
        case .brown: "Prologue"
        }
    }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .purple: Color.purple
        case .green: Color(.fitness)
        case .brown: Color.brown
        case .red: Color.red
        case .orange: Color.orange
        case .yellow: Color.yellow
        case .mono: Color(.monochrome)
        case .barbie: Color(.barbie)
        }
    }

    var safeTint: Color {
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

    var label: LocalizedStringKey {
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
    case books
    case podcasts
    case music
    case barbie
    case mono
    case plex
    case telegram
    case warp
    case atp

    var id: Self { self }

    var data: AppIconData {
        switch self {
        case .factory: AppIconData.factory
        case .music: AppIconData.music
        case .podcasts: AppIconData.podcasts
        case .books: AppIconData.books
        case .mono: AppIconData.mono
        case .barbie: AppIconData.barbie
        case .plex: AppIconData.plex
        case .telegram: AppIconData.telegram
        case .warp: AppIconData.warp
        case .atp: AppIconData.atp
        }
    }
}

struct AppIconData {
    var label: LocalizedStringKey
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

    static var podcasts: Self {
        .init(label: "Podcasts", asset: "AppIconPodcasts", locked: false)
    }

    static var music: Self {
        .init(label: "Music", asset: "AppIconMusic", locked: false)
    }

    static var books: Self {
        .init(label: "Books", asset: "AppIconBooks", locked: false)
    }

    static var mono: Self {
        .init(label: "Monochrome", asset: "AppIconMono", locked: true)
    }

    static var barbie: Self {
        .init(label: "Barbie", asset: "AppIconBarbie", locked: true)
    }

    static var plex: Self {
        .init(label: "Plex", asset: "AppIconPlex", locked: true)
    }

    static var telegram: Self {
        .init(label: "Telegram", asset: "AppIconTelegram", locked: true)
    }

    static var warp: Self {
        .init(label: "Warp", asset: "AppIconWarp", locked: true)
    }

    static var atp: Self {
        .init(label: "ATP", asset: "AppIconATP", locked: true)
    }
}
