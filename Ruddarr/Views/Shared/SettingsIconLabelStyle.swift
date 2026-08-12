import SwiftUI

struct SettingsIconLabelStyle: LabelStyle {
    var iconScale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .tint(.primary)
        } icon: {
            configuration.icon
                .foregroundColor(.primary)
                #if os(iOS)
                    .scaleEffect(iconScale)
                #endif
        }
        .lineLimit(1)
    }
}

extension LabelStyle where Self == SettingsIconLabelStyle {
    static var settingsIcon: Self {
        .init()
    }

    static func settingsIcon(iconScale: CGFloat) -> Self {
        .init(iconScale: iconScale)
    }
}

#Preview {
    Label(String("Home"), systemImage: "house")
        .labelStyle(.settingsIcon(iconScale: 0.8))
}
