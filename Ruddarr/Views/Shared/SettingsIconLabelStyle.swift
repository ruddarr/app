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

#Preview {
    Label(String("Home"), systemImage: "house")
        .labelStyle(SettingsIconLabelStyle(iconScale: 0.8))
}
