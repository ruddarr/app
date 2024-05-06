import SwiftUI

struct Bullet: View {
    var body: some View {
        Text(verbatim: "•")
    }
}

struct ToolbarMonitorButton: View {
    @Binding var monitored: Bool

    var body: some View {
        Circle()
            .fill(.secondarySystemBackground)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "bookmark")
                    .font(.system(size: 11, weight: .bold))
                    .symbolVariant(monitored ? .fill : .none)
                    .foregroundStyle(.tint)
            }
    }
}

struct ToolbarActionButton: View {
    var body: some View {
        Circle()
            .fill(.secondarySystemBackground)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "ellipsis")
                    .symbolVariant(.fill)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tint)
            }
    }
}
