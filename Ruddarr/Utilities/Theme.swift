import SwiftUI

enum Theme: String, Identifiable, CaseIterable {
    case blue = "Blue"
    case red = "Red"
    case purple = "Purple"

    static let factory = Theme.purple

    var id: Self { self }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .red: Color.red
        case .purple: Color.purple
        }
    }
}
