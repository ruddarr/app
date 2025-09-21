import SwiftUI

struct LabeledGroupBox<Content: View, Label: View>: View {
    let content: () -> Content
    let label: () -> Label

    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label) {
        self.content = content
        self.label = label
    }

    init(@ViewBuilder content: @escaping () -> Content) where Label == EmptyView {
        self.content = content
        self.label = { EmptyView() }
    }

    var body: some View {
        #if os(iOS)
            GroupBox {
                content()
            } label: {
                label()
            }
            .groupBoxStyle(RoundedGroupBox())
        #else
            GroupBox {
                VStack(alignment: .leading) {
                    label()
                    content()
                }
                .padding(6)
            }
        #endif
    }
}

struct RoundedGroupBox: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            configuration.content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.card)
        )
    }
}

#Preview {
    LabeledGroupBox {
        Text(verbatim: "Consequat voluptate culpa eu enim voluptate amet cillum est do esse irure sit laborum.")
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    } label: {
        Text(verbatim: "Label")
    }
    .padding(.bottom)
}
