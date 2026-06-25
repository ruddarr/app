import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

struct Downloading: View {
    var body: some View {
        Image(systemName: "arrow.down.circle")
            .symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 1.0)))
    }
}

#Preview {
    Loading()
}
