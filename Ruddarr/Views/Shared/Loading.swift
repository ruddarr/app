import SwiftUI

struct Loading: View {
    var body: some View {
        ProgressView("Loading...")
            .tint(.secondary)
    }
}

#Preview {
    Loading()
}
