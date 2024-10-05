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
        case .blue: String(localized: "Mail", comment: "Localized name of Apple's Mail app")
        case .purple: String(localized: "Podcasts", comment: "Localized name of Apple's Podcasts app")
        case .green: String(localized: "Fitness", comment: "Localized name of Apple's Fitness app")
        case .red: String(localized: "Music", comment: "Localized name of Apple's Music app")
        case .orange: String(localized: "Watch", comment: "Localized name of Apple's Watch app")
        case .yellow: String(localized: "Notes", comment: "Localized name of Apple's Notes app")
        case .mono: String(localized: "Books", comment: "Localized name of Apple's Books app")
        case .barbie: String(localized: "Barbie")
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

    var label: String {
        data.label
    }

    var locked: Bool {
        data.locked
    }

    var preview: String {
        "AppIconPreview\(data.asset)"
    }

    var asset: String {
        self == .factory ? "AppIcon" : "AppIcon\(data.asset)"
    }
}

struct AppIconData {
    var label: String
    var asset: String
    var locked: Bool

    static var factory: Self {
        .init(label: String(localized: "Default"), asset: "Default", locked: false)
    }

    static var podcasts: Self {
        .init(label: String(localized: "Podcasts"), asset: "Podcasts", locked: false)
    }

    static var music: Self {
        .init(label: String(localized: "Music"), asset: "Music", locked: false)
    }

    static var books: Self {
        .init(label: String(localized: "Books"), asset: "Books", locked: false)
    }

    static var mono: Self {
        .init(label: String(localized: "Monochrome", comment: "Name of the 'Monochrome' theme"), asset: "Mono", locked: true)
    }

    static var barbie: Self {
        .init(label: String(localized: "Barbie"), asset: "Barbie", locked: true)
    }

    static var plex: Self {
        .init(label: "Plex", asset: "Plex", locked: true)
    }

    static var telegram: Self {
        .init(label: "Telegram", asset: "Telegram", locked: true)
    }

    static var warp: Self {
        .init(label: "Warp", asset: "Warp", locked: true)
    }

    static var atp: Self {
        .init(label: "ATP", asset: "ATP", locked: true)
    }
}
