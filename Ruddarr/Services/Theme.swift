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

    var label: String {
        switch self {
        case .blue: String(localized: "Mail")
        case .purple: String(localized: "Podcasts")
        case .green: String(localized: "Fitness")
        case .red: String(localized: "Music")
        case .orange: String(localized: "Watch")
        case .yellow: String(localized: "Notes")
        case .mono: String(localized: "Books")
        case .barbie: String(localized: "Barbie")
        case .brown: String(localized: "Prologue")
        }
    }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .purple: Color.purple
        case .green: Color("Fitness")
        case .brown: Color.brown
        case .red: Color.red
        case .orange: Color.orange
        case .yellow: Color.yellow
        case .mono: Color("Monochrome")
        case .barbie: Color("Barbie")
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
        switch self {
        case .automatic: String(localized: "Automatic")
        case .light:  String(localized: "Light")
        case .dark:  String(localized: "Dark")
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
    case mono
    case barbie
    case plex
    case telegram
    case warp

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
        .init(label: String(localized: "Default"), asset: "AppIcon", locked: false)
    }

    static var podcasts: Self {
        .init(label: String(localized: "Podcasts"), asset: "AppIconPodcasts", locked: false)
    }

    static var music: Self {
        .init(label: String(localized: "Music"), asset: "AppIconMusic", locked: false)
    }

    static var books: Self {
        .init(label: String(localized: "Books"), asset: "AppIconBooks", locked: false)
    }

    static var mono: Self {
        .init(label: String(localized: "Monochrome"), asset: "AppIconMono", locked: true)
    }

    static var barbie: Self {
        .init(label: String(localized: "Barbie"), asset: "AppIconBarbie", locked: true)
    }

    static var plex: Self {
        .init(label: String(localized: "Plex"), asset: "AppIconPlex", locked: true)
    }

    static var telegram: Self {
        .init(label: String(localized: "Telegram"), asset: "AppIconTelegram", locked: true)
    }

    static var warp: Self {
        .init(label: "Warp", asset: "AppIconWarp", locked: true)
    }
}
