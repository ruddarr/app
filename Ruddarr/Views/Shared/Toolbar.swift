import SwiftUI

struct Bullet: View {
    var body: some View {
        Text(verbatim: "•")
    }
}

struct ToolbarFilterBadge: View {
    var body: some View {
        Image(systemName: "circle")
            .symbolVariant(.fill)
            .foregroundStyle(.primary)
            .overlay {
                Circle().stroke(.systemBackground, lineWidth: 5)
            }
            .scaleEffect(0.35)
            .offset(x: 8, y: -7)
    }
}

struct ToolbarMonitorButton: View {
    @Binding var monitored: Bool

    var body: some View {
        Image(systemName: "bookmark")
            .symbolVariant(monitored ? .fill : .none)
            .font(.subheadline)
            .tint(.primary)
    }
}

struct ToolbarActionButton: View {
    var body: some View {
        Image(systemName: "ellipsis")
    }
}
