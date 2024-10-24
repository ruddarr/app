import SwiftUI

struct ActionView: View {
    var url: URL?
    var dismiss: () -> Void

    @State private var isPresented: Bool = true

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented, onDismiss: dismiss) {
                sheet.presentationDetents([.fraction(0.2)])
            }
    }

    @ViewBuilder
    var sheet: some View {
        ZStack(alignment: .topTrailing) {
            close

            VStack(alignment: .leading) {
                if false {
                    // Text(url.absoluteString)

                    Link("Calendar", destination: URL(string: "ruddarr://calendar")!)
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Adding")
                }
            }
        }
    }

    var close: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .symbolVariant(.circle.fill)
                .scaleEffect(1.65)
                .tint(.gray)
                .foregroundStyle(
                    .secondary,
                    colorScheme == .dark
                        ? Color(UIColor.tertiarySystemBackground)
                        : Color(UIColor.secondarySystemBackground)
                )
        }
        .buttonStyle(.plain)
        .zIndex(999)
    }
}
