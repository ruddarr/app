import SwiftUI

struct CloseButton: View {
    var callback: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            callback()
        } label: {
            Image(systemName: "xmark")
                .symbolVariant(.circle.fill)
                .scaleEffect(1.65)
                .tint(.gray)
                .foregroundStyle(
                    .primary,
                    colorScheme == .dark
                        ? .tertiarySystemBackground
                        : .secondarySystemBackground
                )
        }
        .buttonStyle(.plain)
        .padding(.top)
        .padding(.trailing)
        .zIndex(999)
    }
}

#Preview {
    CloseButton { }
}
