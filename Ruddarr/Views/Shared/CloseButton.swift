import SwiftUI

struct CloseButton: View {
    var callback: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button {
            callback()
        } label: {
            Image(systemName: "xmark")
                .padding(10)
                .fontWeight(.semibold)
                .glassEffect()
        }
        .tint(.primary)
        .padding(.top, 12)
        .padding(.trailing, 8)
        .zIndex(999)
    }
}

#Preview {
    Group {
        CloseButton { }
    }
    .tint(.red)
}
