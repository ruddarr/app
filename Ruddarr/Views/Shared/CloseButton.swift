import SwiftUI

struct CloseButton: View {
    var callback: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            callback()
        } label: {
            Image(systemName: "xmark")
                .padding(3)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(.top, 12)
        .padding(.trailing, 8)
        .zIndex(999)
    }
}

#Preview {
    CloseButton { }
}
