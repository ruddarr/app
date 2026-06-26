import Combine
import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

struct Downloading: View {
    var color: Color = .secondary
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Image(systemName: "arrow.down.circle")
            .symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 0.5)))
            .symbolRenderingMode(.palette)
            .foregroundStyle(settings.theme.tint, color)
    }
}

#Preview {
    Loading()
}

#Preview("Downloading") {
    HStack {
        Downloading()
        Downloading(color: .lightGray)
        Downloading(color: .red)
    }
    .withAppState()
}
