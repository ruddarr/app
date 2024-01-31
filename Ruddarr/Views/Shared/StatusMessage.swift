import SwiftUI

struct StatusMessage: View {
    var text: String

    @Binding var isPresenting: Bool

    func hide() {
        withAnimation {
            isPresenting = false
        }
    }

    var body: some View {
        if isPresenting {
            HStack {
                Text(text)
                    .fontWeight(.semibold)
                    .padding()
                    .padding(.horizontal)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .transition(
                .opacity.combined(with: .scale)
            )
            .onTapGesture(perform: hide)
            .onAppear {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    hide()
                }
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
            StatusMessage(text: "Testing", isPresenting: $show)
        }
}
