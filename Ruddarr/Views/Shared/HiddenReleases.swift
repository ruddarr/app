import SwiftUI

struct HiddenReleases: View {
    var body: some View {
        Text("Some releases are hidden by the selected filters.")
            .foregroundStyle(.secondary)
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .listRowSeparator(.hidden, edges: .bottom)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    HiddenReleases()
}
