import SwiftUI

struct SettingsIconLabelStyle: LabelStyle {
    var color: Color
    @ScaledMetric(relativeTo: .body) var size: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var iconSize = 28

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .tint(.primary)
        } icon: {
            configuration.icon
                .font(.system(size: size))
                .foregroundColor(.white)
                #if os(iOS)
                    .background(
                        RoundedRectangle(cornerRadius: (10 / 57) * iconSize)
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(color)
                    )
                #endif
        }
        .lineLimit(1)
    }
}
