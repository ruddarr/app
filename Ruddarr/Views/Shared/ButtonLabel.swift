import SwiftUI

struct ButtonLabel: View {
    var text: String
    var icon: String

    var isLoading: Bool = false

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Label {
                    Text(text)
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
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        Button {
            //
        } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle")
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .withSettings()

        Button {
            //
        } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle", isLoading: true)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .withSettings()
    }
}
