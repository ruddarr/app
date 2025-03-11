import SwiftUI

struct ButtonLabel: View {
    private var label: Text
    private var icon: String
    private var isLoading: Bool = false

    init(text: String, icon: String, isLoading: Bool = false) {
        self.label = Text(text)
        self.icon = icon
        self.isLoading = isLoading
    }

    init(text: LocalizedStringKey, icon: String, isLoading: Bool = false) {
        self.label = Text(text)
        self.icon = icon
        self.isLoading = isLoading
    }

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Label {
            label
                .font(.callout)
        } icon: {
            Image(systemName: icon)
                .imageScale(.medium)
                .frame(maxHeight: 20)
        }
        .opacity(isLoading ? 0 : 1)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .fontWeight(.semibold)
        .foregroundStyle(settings.theme.tint)
        .padding(.vertical, 6)
        .animation(.spring(duration: 0.2), value: isLoading)
    }
}

#Preview {
    @Previewable @State var isLoading: Bool = false

    VStack {
        Button {
            isLoading.toggle()
        } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle", isLoading: isLoading)
        }
            .buttonStyle(.bordered)
            .tint(.secondary)

        Button { } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle", isLoading: true)
        }
            .buttonStyle(.bordered)
            .tint(.secondary)
    }.withAppState()
}
