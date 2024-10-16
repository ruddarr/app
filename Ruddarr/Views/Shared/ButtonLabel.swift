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
        Group {
            if isLoading {
                ProgressView()
            } else {
                Label {
                    label
                        .font(.callout)
                } icon: {
                    Image(systemName: icon)
                        .imageScale(.medium)
                        .frame(maxHeight: 20)
                }
            }
        }
        .fontWeight(.semibold)
        .foregroundStyle(settings.theme.tint)
        .padding(.vertical, 6)
    }
}

#Preview {
    VStack {
        Button { } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle")
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
