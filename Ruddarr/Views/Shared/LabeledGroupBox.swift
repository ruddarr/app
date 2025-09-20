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
