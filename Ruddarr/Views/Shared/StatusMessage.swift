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
            .sensoryFeedback(.success, trigger: isPresenting)
            .onTapGesture(perform: hide)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    hide()
                }
            }
        }
    }
}

#Preview {
    @State var show = true

    return Text("")
        .overlay {
            StatusMessage(text: "Testing", isPresenting: $show)
        }
}
