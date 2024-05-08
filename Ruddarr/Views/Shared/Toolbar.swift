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
