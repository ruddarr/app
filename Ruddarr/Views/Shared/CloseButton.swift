import SwiftUI

struct CloseButton: View {
    var callback: () -> Void

    var body: some View {
        Button {
            callback()
        } label: {
            Image(systemName: "xmark")
                .symbolVariant(.circle.fill)
                .scaleEffect(1.65)
                .tint(.gray)
                .foregroundStyle(.primary, .tertiarySystemBackground)
        }
        .padding(.top)
        .padding(.trailing)
        .zIndex(999)
    }
}

#Preview {
    CloseButton { }
}
