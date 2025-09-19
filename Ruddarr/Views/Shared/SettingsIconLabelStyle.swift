import SwiftUI

struct SettingsIconLabelStyle: LabelStyle {
    var font: Font = .subheadline

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .tint(.primary)
        } icon: {
            configuration.icon
                .font(font)
                .foregroundColor(.primary)
        }
        .lineLimit(1)
    }
}
