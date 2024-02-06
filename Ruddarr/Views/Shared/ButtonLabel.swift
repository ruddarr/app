import SwiftUI

struct ButtonLabel: View {
    var text: String
    var icon: String

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Label {
            Text(text)
                .font(.callout)
        } icon: {
            Image(systemName: icon)
                .imageScale(.medium)
                .frame(maxHeight: 20)
        }
        .fontWeight(.semibold)
        .foregroundStyle(settings.theme.tint)
        .padding(.vertical, 6)
        .padding(.horizontal)
    }
}

#Preview {
    Button {
        //
    } label: {
        ButtonLabel(text: "Download", icon: "arrow.down.circle")
    }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .withSettings()
}
