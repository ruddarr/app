import SwiftUI

enum Theme: String, Identifiable, CaseIterable {
    case blue
    case red
    case purple
    case factory

    var id: Self { self }

    var tint: Color {
        switch self {
        case .blue: Color.blue
        case .red: Color.red
        case .purple, .factory: Color.purple
        }
    }
}
