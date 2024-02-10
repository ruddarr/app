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
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"

    var id: Self { self }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
