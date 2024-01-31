import SwiftUI

struct StatusMessage: View {
    var text: String
    var icon: String

    @Binding var isPresenting: Bool

    init(text: String, icon: String, isPresenting: Binding<Bool>) {
        self.text = text
        self.icon = icon
        self._isPresenting = isPresenting
    }

    func hide() {
        withAnimation {
            isPresenting = false
        }
    }

    var body: some View {
        if isPresenting {
            HStack {
                Label(text, systemImage: icon)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .padding()
            }
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .transition(
                .opacity.combined(with: .scale)
            )
            .onTapGesture(perform: hide)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    hide()
                }

                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            }
        }
    }
}

#Preview {
    @State var show = true

    return Rectangle()
        .fill(.background)
        .frame(width: .infinity, height: .infinity)
        .overlay {
            StatusMessage(
                text: "Unmonitored",
                icon: "bookmark",
                isPresenting: $show
            )
        }
}
