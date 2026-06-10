import SwiftUI

struct MediaGridCount<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) {
            content
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
        .padding(.bottom)
    }
}

#Preview {
    VStack {
        MediaGridCount {
            Text(verbatim: "128 Movies")
        }

        MediaGridCount {
            Text(verbatim: "42 Series")
            Bullet()
            Text(verbatim: "1,203 Episodes")
        }
    }
    .withAppState()
}
