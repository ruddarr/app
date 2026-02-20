import SwiftUI

struct MediaGridPosterOverlay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            content
        }
        .font(.body)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

extension Image.Scale {
    static var gridItem: Image.Scale {
        switch Platform.deviceType {
        case .phone: .small
        case .mac: .large
        default: .medium
        }
    }
}
